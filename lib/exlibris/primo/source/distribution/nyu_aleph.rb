module Exlibris::Primo::Source::Local
  # == Overview
  # NYUAleph is an Exlibris::Primo::Source::Aleph that expands Primo availlibrary
  # elements based on of Aleph items return from the Aleph REST APIs.
  # It stores metadata from these items ub the ServiceType#view[:source_data]
  # element that can be used by custom controllers to extend patron services, 
  # including request and paging functionality.
  # NYUAleph also provides coverage metadata based on bib and holding 
  # information from the Aleph bib and holdings REST APIs.
  #
  # == Benchmarks
  # The following benchmarks were run on SunOS 5.10 Generic_141414-08 sun4u sparc SUNW,Sun-Fire-V240.
  #       Rehearsal -----------------------------------------------------------
  #       PrimoSource - NYUAleph:   2.120000   0.020000   2.140000 (  3.436712)
  #       -------------------------------------------------- total: 2.140000sec
  #       
  #                                     user     system      total        real
  #       PrimoSource - NYUAleph:   2.130000   0.030000   2.160000 (  3.486879)
  class NYUAleph < Exlibris::Primo::Source::Aleph
    @attribute_aliases = Exlibris::Primo::Source::Aleph.attribute_aliases
    @decode_variables = Exlibris::Primo::Source::Aleph.decode_variables
    @source_data_elements = {
      :aleph_url => :source_url,
      :aleph_sub_library_code => :aleph_sub_library_code,
      :aleph_item_id => :aleph_item_id,
      :aleph_item_adm_library => :aleph_item_adm_library,
      :aleph_item_sub_library_code => :aleph_item_sub_library_code,
      :aleph_item_collection_code => :aleph_item_collection_code,
      :aleph_item_doc_number => :aleph_item_doc_number,
      :aleph_item_sequence_number => :aleph_item_sequence_number,
      :aleph_item_barcode => :aleph_item_barcode,
      :aleph_item_status_code => :aleph_item_status_code,
      :aleph_item_process_status_code => :aleph_item_process_status_code,
      :aleph_item_circulation_status => :aleph_item_circulation_status,
      :aleph_item_location => :aleph_item_location,
      :aleph_item_description => :aleph_item_description,
      :aleph_item_hol_doc_number => :aleph_item_hol_doc_number
    }

    class << self; attr_reader :source_data_elements end

    # Overwrites Exlibris::Primo::Source::Aleph#new
    def initialize(parameters={})
      super(parameters)
      @aleph_helper ||= Exlibris::Aleph::Config::Helper.instance()
      unless parameters[:holding].is_a?(NYUAleph)
        # Only process this stuff the first NYUAleph is call, 
        # i.e. on :to_primo_source, since we don't want to 
        # make these expensive calls twice.
        # Get Aleph record from REST API
        aleph_record = Exlibris::Aleph::Record.new(
          aleph_doc_library, 
          aleph_doc_number, 
          aleph_config["rest_url"]
        ) unless aleph_config.nil?
        begin
          # Exlibris::Aleph::Record :items will raise an exception if the response isn't valid XML.
          # We'll handle the exception, ignore the Aleph stuff and 
          # send a message to the necessary parties that something is up.
          @aleph_items ||= 
            (aleph_record.nil? or display_type.upcase == "JOURNAL") ? 
              {} : aleph_record.items 
          @coverage ||= get_coverage(aleph_record)
          # Don't need to exclude JOURNALS explicitly since we
          # handled them above.
          @getting_aleph_holdings ||= !(@aleph_items.empty? or @aleph_items.size > @max_holdings)
        rescue Exception => e
          RAILS_DEFAULT_LOGGER.error("Error getting data from Aleph REST APIs. #{e.message}")
          @aleph_items = []
          @coverage = []
          # TODO: Figure out if this is the right thing to do.
          # On the one hand, if Aleph REST APIs are down, Aleph may be down,
          # so we don't want to send users to a dead link.
          # On the other hand, if they just came from Primo, they don't want to 
          # go back and Aleph may not be down, just the REST APIs.
          @url = primo_url
          @getting_aleph_holdings = false
          # Alert the authorities to the problem
          alert_the_authorities e
        end
      else
        # Only process this stuff after :expand is called, 
        # because we don't have correct data before
        # Set library as the Aleph sub library if it exists.
        aleph_sub_library = @aleph_helper.sub_library_text(
          :sub_library_code => @aleph_item_sub_library_code 
          ) unless @aleph_helper.nil?
        @library = aleph_sub_library unless aleph_sub_library.nil?
        # Set id_one as the Aleph collection if it exists.
        aleph_collection = @aleph_helper.collection_text(
            :adm_library_code => @aleph_item_adm_library.downcase,
            :sub_library_code => @aleph_item_sub_library_code,
            :collection_code => @aleph_item_collection_code
            ) unless @aleph_helper.nil? or @aleph_item_adm_library.nil?
        @id_one = aleph_collection unless aleph_collection.nil?
        # Set status and status code.
        aleph_status_code, aleph_status = nil, nil
        # Loop through source config for statuses
        aleph_config["statuses"].each { |aleph_config_status_code, aleph_config_status|
          # Set checked out as Aleph status and code
          aleph_status_code = aleph_config_status_code and 
            aleph_status = "Due: " + @aleph_item_circulation_status and
              break if (aleph_config_status_code == "checked_out" and 
                aleph_config_status === @aleph_item_circulation_status)
          # Set circulation statuses like On Shelf, Billed as Lost, as Aleph status and code
          aleph_status_code = aleph_config_status_code and
              break if (aleph_config_status.instance_of?(Array) and 
                aleph_config_status.include?(@aleph_item_circulation_status))
        } unless aleph_config.nil?
        if (aleph_status_code.nil?)
          # Set Aleph web text as Aleph status if we haven't already gotten the Aleph status
          aleph_status = @aleph_helper.item_web_text(
            :adm_library_code => @aleph_item_adm_library.downcase,
            :sub_library_code => @aleph_item_sub_library_code,
            :item_status_code => @aleph_item_status_code,
            :item_process_status_code => @aleph_item_process_status_code
          ) unless @aleph_helper.nil? or @aleph_item_adm_library.nil?
          # Set code as "overridden_by_nyu_aleph"
          aleph_status_code = "overridden_by_nyu_aleph" unless aleph_status.nil?
        end
        # Set status code if we have it.
        @status_code = aleph_status_code unless aleph_status_code.nil?
        # Set status.
        @status = (aleph_status.nil?) ? 
          decode(:status, {:address => "statuses"}, true) : aleph_status
        if requestable?
          # Aleph doesn't work right so we have to push the patron to the Aleph holdings page!
          @request_url = url
        end
        # We're through a second time, so we should be alright to 
        # to our ajax request stuff. We don't need to put this in
        # requestable, since ILL doesn't need a request URL.
        # TODO: Probably should specify the gap so it's clear.  
        # Likely "Billed as Lost" and other circ statuses.
        @request_link_supports_ajax_call = true
        @source_data[:illiad_url] = aleph_config["illiad_url"]
        # Merge the rest of the source data based on class array.
        source_data = {} and self.class.source_data_elements.each { |element, instance_variable_name|
          source_data[element] = instance_variable_get("@#{instance_variable_name}")
        }
        @source_data.merge!(source_data)
      end
    end
    
    # Overwrites Exlibris::Primo::Source::Aleph#expand
    def expand
      aleph_holdings = get_aleph_holdings
      return (aleph_holdings.empty?) ? 
        super : aleph_holdings if getting_aleph_holdings?
      super
    end
    
    # Overwrites Exlibris::Primo::Source::Aleph#dedup?
    def dedup?
      @dedup ||= getting_aleph_holdings?
    end

    private
    def requestable?
      aleph_item_permissions = @aleph_helper.item_permissions(
        :adm_library_code => @aleph_item_adm_library.downcase,
        :sub_library_code => @aleph_item_sub_library_code,
        :item_status_code => @aleph_item_status_code,
        :item_process_status_code => @aleph_item_process_status_code
      ) unless @aleph_helper.nil? or @aleph_item_adm_library.nil?
      return super if aleph_item_permissions.nil?
      # Check tab 15 requestable item statuses and requestable circ statuses
      return false if ((["N"].include?(aleph_item_permissions[:hold_request]) and 
        ["N"].include?(aleph_item_permissions[:photocopy_request])) or 
        ["Reshelving"].include?(@aleph_item_circulation_status))
      return true
    end

    def get_coverage(aleph_record)
      require 'hpricot'
      locations_seen = []
      coverage = []
      return coverage unless display_type.upcase == "JOURNAL"
      # Get aleph bib XML and raise exception if there is an error.
      aleph_bib = aleph_record.bib
      raise "Error getting bib from Aleph REST APIs. #{aleph_record.error}" unless aleph_record.error.nil?
      # Parse and process bib XML
      # First look at bib 866 and record sub_library and collection (through aleph config mappings)
      Hpricot.XML(aleph_bib).search("//datafield[@tag='866']") do |bib_866|
        bib_866_l = bib_866.at(
          "subfield[@code='l']"
        ).inner_text unless bib_866.at("subfield[@code='l']").nil?
        h = aleph_config["866$l_mappings"]
        next if h[bib_866_l].nil?
        bib_866_sub_library_code = h[bib_866_l]['sub_library']
        if @aleph_sub_library_code.upcase == bib_866_sub_library_code.upcase
          bib_866_collection_code = h[bib_866_l]['collection']
          bib_866_adm_library = @aleph_helper.sub_library_adm(
            :sub_library_code => bib_866_sub_library_code
          ) unless @aleph_helper.nil?
          bib_866_j = bib_866.at(
            "subfield[@code='j']"
          ).inner_text unless bib_866.at("subfield[@code='j']").nil?
          bib_866_k = bib_866.at(
            "subfield[@code='k']"
          ).inner_text unless bib_866.at("subfield[@code='k']").nil?
          bib_866_collection = @aleph_helper.collection_text(
            :adm_library_code => bib_866_adm_library.downcase,
            :sub_library_code => bib_866_sub_library_code,
            :collection_code => bib_866_collection_code
          ) unless @aleph_helper.nil? or bib_866_adm_library.nil?
          coverage.push(
            "Available in #{bib_866_collection}: #{build_coverage_string(bib_866_j, bib_866_k)}".strip
          ) unless bib_866_collection.nil? or bib_866_j.nil? and bib_866_k.nil?
          locations_seen.push({
            :adm_library => bib_866_adm_library, 
            :sub_library_code => bib_866_sub_library_code 
          })
        end
      end
      # Get aleph holding XML.
      aleph_holdings = aleph_record.holdings
      # Parse and process holding XML
      # Now look at holding 866 and record sub_library and collection 
      # to see if there is anything we missed
      Hpricot.XML(aleph_holdings).search("//holding") do |aleph_holding|
        holding_sub_library_code = aleph_holding.at(
          "//datafield[@tag='852']/subfield[@code='b']"
        ).inner_text unless aleph_holding.at("//datafield[@tag='852']/subfield[@code='b']").nil?
        if @aleph_sub_library_code.upcase == holding_sub_library_code.upcase
          holding_adm_library = @aleph_helper.sub_library_adm(
            :sub_library_code => holding_sub_library_code
          ) unless @aleph_helper.nil?
          holding_collection_code = aleph_holding.at(
            "//datafield[@tag='852']/subfield[@code='c']"
          ).inner_text unless aleph_holding.at("//datafield[@tag='852']/subfield[@code='c']").nil?
          next if locations_seen.include?({
            :adm_library => holding_adm_library, 
            :sub_library_code => holding_sub_library_code
          })
          holding_collection = @aleph_helper.collection_text(
            :adm_library_code => holding_adm_library.downcase,
            :sub_library_code => holding_sub_library_code,
            :collection_code => holding_collection_code
          ) unless @aleph_helper.nil? or holding_adm_library.nil?
          aleph_holding.search("//datafield[@tag='866']") do |holding_866|
            holding_866_a = holding_866.at(
              "subfield[@code='a']"
            ).inner_text unless holding_866.at("subfield[@code='a']").nil?
            coverage.push(
              "Available in #{holding_collection}: #{holding_866_a.gsub(",", ", ")}".strip
            ) unless holding_collection.nil? or holding_866_a.nil?
          end
        end
      end
      return coverage
    end
    
    def get_aleph_holdings
      aleph_holdings = []
      return aleph_holdings if @aleph_items.nil? 
      @aleph_items.each do |aleph_item|
        aleph_item_parameters = {
          :holding => self,
          :aleph_item_id => aleph_item["href"].match(/items\/(.+)$/)[1],
          :aleph_item_adm_library => aleph_item["z30"]["translate_change_active_library"],
          :aleph_sub_library_code => aleph_item["z30_sub_library_code"].strip,
          :aleph_item_sub_library_code => aleph_item["z30_sub_library_code"].strip,
          :aleph_item_collection_code => aleph_item["z30_collection_code"],
          :aleph_item_doc_number => aleph_item["z30"]["z30_doc_number"],
          :aleph_item_sequence_number => aleph_item["z30"]["z30_item_sequence"].strip,
          :aleph_item_barcode => aleph_item["z30"]["z30_barcode"],
          :aleph_item_status_code => aleph_item["z30_item_status_code"],
          :aleph_item_process_status_code => aleph_item["z30_item_process_status_code"],
          :aleph_item_circulation_status => aleph_item["status"],
          :aleph_item_location => aleph_item["z30"]["z30_call_no"],
          :aleph_item_description => aleph_item["z30"]["z30_description"],
          :aleph_item_hol_doc_number => aleph_item["z30"]["z30_hol_doc_number"],
          :library_code => aleph_item["z30_sub_library_code"].strip,
          :id_two => process_aleph_call_number(aleph_item).gsub("&nbsp;", " ")
        }
        aleph_holdings.push(self.class.new(aleph_item_parameters))
      end
      RAILS_DEFAULT_LOGGER.warn(
        "No holdings processed from Aleph items in #{self.class}: #{self.record_id}."
      ) if aleph_holdings.empty? and getting_aleph_holdings?
      return aleph_holdings
    end
    
    def getting_aleph_holdings?
      @getting_aleph_holdings
    end

    def process_aleph_call_number(aleph_item)
      return "" if aleph_item.nil? or 
        (aleph_item["z30"].fetch("z30_call_no", "").nil? and 
        aleph_item["z30"].fetch("z30_description", "").nil?)
      return "("+ 
        de_marc_call_number(aleph_item["z30"].fetch("z30_call_no", ""))+ 
        ")" if aleph_item["z30"].fetch("z30_description", "").nil? 
      return "("+ 
        aleph_item["z30"].fetch("z30_description", "").to_s + 
        ")" if aleph_item["z30"].fetch("z30_call_no", "").nil? 
      return "("+ 
        de_marc_call_number(aleph_item["z30"].fetch("z30_call_no", ""))+ 
        " "+ aleph_item["z30"].fetch("z30_description", "").to_s+ ")"
    end

    def de_marc_call_number(marc_call_number)
      call_number = marc_call_number
      call_number.gsub!(/\$\$h/, "") unless call_number.nil? or 
        call_number.match(/\$\$h/).nil?
      call_number.gsub!(/\$\$i/, " ") unless call_number.nil? or 
        call_number.match(/\$\$i/).nil?
      return call_number
    end

    def build_coverage_string(volumes, years)
      rv = ""
      rv += "VOLUMES: "+ volumes unless volumes.nil? or volumes.empty?
      rv += " (YEARS: "+ years+ ") " unless years.nil? or years.empty?
      return rv
    end
    
    # TODO: Implement to send mail.
    def alert_the_authorities(error)
      puts "Something is amiss. #{error}"
    end
  end
end
