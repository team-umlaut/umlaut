include Exlibris::Aleph
module Exlibris::Primo::Source::Local
  require 'hpricot'

  class NYUAleph < Exlibris::Primo::Source::Aleph
    attr_reader :holdings
    attr_reader :aleph_record
    attr_reader :aleph_bib, :aleph_items, :aleph_holdings
    attr_accessor :aleph_item_id, :aleph_item_adm_library, :aleph_item_sub_library_code, :aleph_item_collection_code, :aleph_item_doc_number, :aleph_item_sequence_number, :aleph_item_barcode
    attr_accessor :aleph_item_status_code, :aleph_item_process_status_code, :aleph_item_circulation_status
    attr_accessor :aleph_item_location, :aleph_item_description, :aleph_item_hol_doc_number
 
    def initialize(e=nil)
      @aleph_config_helper = Exlibris::Aleph::Config::ConfigHelper.instance()
      super(e)
      @aleph_rest_url = aleph_config["rest_url"]
      @request_link_supports_ajax_call = true
    end
    
    def actionable?
      return super if aleph_item_permissions.empty?
      # Check tab 15 requestable item statuses and requestable circ statuses
      return false if ((["N"].include?(aleph_item_permissions[:hold_request]) and ["N"].include?(aleph_item_permissions[:photocopy_request])) or ["Reshelving"].include?(aleph_item_circulation_status))
      return true
    end
    alias requestable? actionable?

    def to_a
      return self.holdings if processing_aleph_items?
      return super
    end
    
    def coverage_str
      locations_seen = []
      unless(@coverage_str)
        coverage_str_a = []
        if display_type.upcase == "JOURNAL"
          # First look at bib 866 and record sublibrary and collection (through aleph config mappings)
          aleph_bib.search("//datafield[@tag='866']") do |bib_866|
            bib_866_l = bib_866.at("subfield[@code='l']").inner_text unless bib_866.at("subfield[@code='l']").nil?
            h = aleph_config["866$l_mappings"]
            next if h[bib_866_l].nil?
            bib_866_sub_library_code = h[bib_866_l]['sub_library']
            if aleph_sub_library_code.upcase == bib_866_sub_library_code.upcase
              bib_866_collection_code = h[bib_866_l]['collection']
              bib_866_adm_library = @aleph_config_helper.aleph_sub_libraries[bib_866_sub_library_code][:library] unless @aleph_config_helper.aleph_sub_libraries[bib_866_sub_library_code].nil?
              bib_866_j = bib_866.at("subfield[@code='j']").inner_text unless bib_866.at("subfield[@code='j']").nil?
              bib_866_k = bib_866.at("subfield[@code='k']").inner_text unless bib_866.at("subfield[@code='k']").nil?
              bib_866_collection = @aleph_config_helper.aleph_collections[bib_866_adm_library.downcase][bib_866_sub_library_code][bib_866_collection_code][:text] unless bib_866_adm_library.nil? or bib_866_sub_library_code.nil? or bib_866_collection_code.nil?
              coverage_str_a.push("Available in #{bib_866_collection}: "+ build_coverage_string(bib_866_j, bib_866_k)) unless bib_866_collection.nil? or bib_866_j.nil? and bib_866_k.nil?
              #locations_seen.push({:adm_library => bib_866_adm_library, :sub_library_code => bib_866_sub_library_code, :collection_code => bib_866_collection_code})
              locations_seen.push({:adm_library => bib_866_adm_library, :sub_library_code => bib_866_sub_library_code})
            end
          end
          # Now look at holding 866 and record sublibrary and collection to see if there is anything we missed
          aleph_holdings.search("//holding") do |aleph_holding|
            holding_sub_library_code = aleph_holding.at("//datafield[@tag='852']/subfield[@code='b']").inner_text unless aleph_holding.at("//datafield[@tag='852']/subfield[@code='b']").nil?
            if aleph_sub_library_code.upcase == holding_sub_library_code.upcase
              holding_adm_library = @aleph_config_helper.aleph_sub_libraries[holding_sub_library_code][:library] unless @aleph_config_helper.aleph_sub_libraries[holding_sub_library_code].nil?
              holding_collection_code = aleph_holding.at("//datafield[@tag='852']/subfield[@code='c']").inner_text unless aleph_holding.at("//datafield[@tag='852']/subfield[@code='c']").nil?
              #next if locations_seen.include?({:adm_library => holding_adm_library, :sub_library_code => holding_sub_library_code, :collection_code => holding_collection_code})
              next if locations_seen.include?({:adm_library => holding_adm_library, :sub_library_code => holding_sub_library_code})
              holding_collection = @aleph_config_helper.aleph_collections[holding_adm_library.downcase][holding_sub_library_code][holding_collection_code][:text] unless holding_adm_library.nil? or holding_sub_library_code.nil? or holding_collection_code.nil?
              aleph_holding.search("//datafield[@tag='866']") do |holding_866|
                holding_866_a = holding_866.at("subfield[@code='a']").inner_text unless holding_866.at("subfield[@code='a']").nil?
                coverage_str_a.push("Available in #{holding_collection}: "+ holding_866_a.gsub(",", ", ")) unless holding_collection.nil? or holding_866_a.nil?
              end
            end
          end
          
=begin          
          bib.search("//varfield[@id='866']") do |e_866|
            id_attribute = e_866.previous_sibling.get_attribute("id") unless e_866.previous_sibling.nil?
            next if id_attribute.nil?
            if id_attribute.to_s == "852"
              e_852 = e_866.previous_sibling
              e_852_b = e_852.at("subfield[@label='b']").inner_text unless e_852.at("subfield[@label='b']").nil?
              e_852_c = e_852.at("subfield[@label='c']").inner_text unless e_852.at("subfield[@label='c']").nil?
              if aleph_sub_library_code.upcase == e_852_b.upcase
                coverage_str_a.push("Available in #{map(e_852_c, collections_config)}: "+ e_866.at("subfield[@label='a']").inner_text.gsub(",", ", ")) unless e_866.at("subfield[@label='a']").nil?
                collections_seen.push(e_852_c)
              end
            end
          end
          bib.response_xml.search("//varfield[@id='866']") do |e_866|
            e_866_l = e_866.at("subfield[@label='l']").inner_text unless e_866.at("subfield[@label='l']").nil?
            h = aleph_config["866$l_mappings"]
            next if h[e_866_l].nil?
            e_866_l_sub_library = h[e_866_l]['sub_library']
            e_866_l_collection = h[e_866_l]['collection']
            next if collections_seen.include?(e_866_l_collection)
            if aleph_sub_library_code.upcase == e_866_l_sub_library.upcase
              e_866_j = e_866.at("subfield[@label='j']").inner_text unless e_866.at("subfield[@label='j']").nil?
              e_866_k = e_866.at("subfield[@label='k']").inner_text unless e_866.at("subfield[@label='k']").nil?
              coverage_str_a.push("Available in #{map(e_866_l_collection, collections_config)}: "+ build_coverage_string(e_866_j, e_866_k)) unless e_866_j.nil? and e_866_k.nil?
            end
          end
=end
        end
        @coverage_str = coverage_str_a.join("<br />") unless coverage_str_a.empty?
      end
      return @coverage_str
    end
    
    def coverage_str_to_a
      coverage_str.split("<br />") unless coverage_str.nil?
    end

    # Override holding.dedup? to tell Primo Searcher whether this requires deduping
    def dedup?
      return processing_aleph_items?
    end

    # Override holding.status to calculate status
    def status
      return @status unless @status.nil?
      h = aleph_config["statuses"]
      return super if h.nil?
      h.each do |k, v| 
        @status_code = k and return @status = "Due: "+ aleph_item_circulation_status if k== "checked_out" and v=== aleph_item_circulation_status
        # Handle circulation statuses like On Shelf, Billed as Lost, etc.
        @status_code = k and return @status = super if v.instance_of?(Array) and v.include?(aleph_item_circulation_status)
      end
      return @status = @aleph_config_helper.aleph_item_mappings[self.aleph_item_adm_library.downcase][aleph_item_permissions[:text]][:web_text] unless aleph_item_permissions.nil? or aleph_item_permissions[:text].nil? or self.aleph_item_adm_library.nil? or @aleph_config_helper.aleph_item_mappings[self.aleph_item_adm_library.downcase][aleph_item_permissions[:text]].nil?
      return @status = super 
    end
    
    # Override holding.library to use config helper
    def library
      return @aleph_sub_library unless (@aleph_sub_library.nil?)
      return super if self.aleph_item_sub_library_code.nil? or @aleph_config_helper.aleph_sub_libraries[self.aleph_item_sub_library_code].nil?
      return @aleph_sub_library = @aleph_config_helper.aleph_sub_libraries[self.aleph_item_sub_library_code][:text]
    end

    # Override holding.collection to use config helper
    def collection
      return @aleph_collection unless (@aleph_collection.nil?)
      return super if self.aleph_item_adm_library.nil? or self.aleph_item_sub_library_code.nil? or self.aleph_item_collection_code.nil?
      return @aleph_collection = @aleph_config_helper.aleph_collections[self.aleph_item_adm_library.downcase][self.aleph_item_sub_library_code][self.aleph_item_collection_code][:text]
    end
    alias aleph_collection collection
    
    protected
    def holdings
      return @holdings if @holdings.kind_of? Array
      @holdings = []
      return @holdings unless processing_aleph_items?
      aleph_items.each do |aleph_item|
        holding = self.class.new(self)
        holding.primo_config = primo_config

        #Aleph properties from item
        holding.aleph_item_id = aleph_item["href"].match(/items\/(.+)$/)[1] 
        holding.aleph_item_adm_library = aleph_item["z30"]["translate_change_active_library"]
        holding.aleph_sub_library_code = aleph_item["z30_sub_library_code"].strip
        holding.aleph_item_sub_library_code = aleph_item["z30_sub_library_code"].strip
        holding.aleph_item_collection_code = aleph_item["z30_collection_code"]
        holding.aleph_item_doc_number = aleph_item["z30"]["z30_doc_number"]
        holding.aleph_item_sequence_number = aleph_item["z30"]["z30_item_sequence"]
        holding.aleph_item_barcode = aleph_item["z30"]["z30_barcode"]
        holding.aleph_item_status_code = aleph_item["z30_item_status_code"]
        holding.aleph_item_process_status_code = aleph_item["z30_item_process_status_code"]
        holding.aleph_item_circulation_status = aleph_item["status"]
        holding.aleph_item_location = aleph_item["z30"]["z30_call_no"]
        holding.aleph_item_description = aleph_item["z30"]["z30_description"]
        holding.aleph_item_hol_doc_number = aleph_item["z30"]["z30_hold_doc_number"]

        holding.library_code = holding.aleph_item_sub_library_code
        holding.status_code = aleph_item_circulation_status
        holding.id_one = aleph_collection
        holding.id_two = aleph_call_number(aleph_item)
        holding.call_number = aleph_call_number(aleph_item)
        holding.record_id = record_id
        holding.original_source_id = original_source_id
        holding.source_id = source_id
        holding.source_record_id = source_record_id

        @holdings.push(holding)
      end
      self.holdings
    end
    
    private
    def processing_aleph_items?
      return !(display_type.upcase == "JOURNAL" or aleph_items.nil? or aleph_items.size > max_holdings)
    end
    
    def aleph_record
      return @aleph_record unless @aleph_record.nil?      
      return @aleph_record = Exlibris::Aleph::Record.new(aleph_bib_library, aleph_bib_number, @aleph_rest_url)
    end

    def aleph_bib
      return @aleph_bib unless @aleph_bib.nil?
      return @aleph_bib = Hpricot.XML(aleph_record.bib)
    end

    def aleph_holdings
      return @aleph_holdings unless @aleph_holdings.nil?
      return @aleph_holdings = Hpricot.XML(aleph_record.holdings)
    end

    def aleph_items
      return @aleph_items unless @aleph_items.nil?
      return @aleph_items = aleph_record.items
    end
    
    def aleph_call_number(aleph_item)
      return "" if aleph_item.nil? or (aleph_item["z30"].fetch("z30_call_no", "").nil? and aleph_item["z30"].fetch("z30_description", "").nil?)
      return "("+ de_marc_call_number(aleph_item["z30"].fetch("z30_call_no", ""))+ ")" if aleph_item["z30"].fetch("z30_description", "").nil? 
      return "("+ aleph_item["z30"].fetch("z30_description", "").to_s + ")" if aleph_item["z30"].fetch("z30_call_no", "").nil? 
      return "("+ de_marc_call_number(aleph_item["z30"].fetch("z30_call_no", ""))+ " "+ aleph_item["z30"].fetch("z30_description", "").to_s+ ")"
    end
    
    def de_marc_call_number(marc_call_number)
      call_number = marc_call_number
      call_number.gsub!(/\$\$h/, "") unless call_number.nil? or call_number.match(/\$\$h/).nil?
      call_number.gsub!(/\$\$i/, " ") unless call_number.nil? or call_number.match(/\$\$i/).nil?
      return call_number
    end

    def aleph_item_permissions
      return @aleph_item_permissions unless @aleph_item_permissions.nil?
      @aleph_item_permissions = {}
      # If item processing status exists, it trumps item status
      return @aleph_item_permissions = @aleph_config_helper.aleph_item_permissions_by_item_process_status_config[self.aleph_item_adm_library.downcase][self.aleph_item_sub_library_code][self.aleph_item_process_status_code] unless self.aleph_item_process_status_code.nil? or @aleph_config_helper.aleph_item_permissions_by_item_process_status_config[self.aleph_item_adm_library.downcase][self.aleph_item_sub_library_code].nil?
      # Otherwise get item status
      return @aleph_item_permissions = @aleph_config_helper.aleph_item_permissions_by_item_status_config[self.aleph_item_adm_library.downcase][self.aleph_item_sub_library_code][self.aleph_item_status_code] unless self.aleph_item_status_code.nil? or @aleph_config_helper.aleph_item_permissions_by_item_status_config[self.aleph_item_adm_library.downcase][self.aleph_item_sub_library_code].nil?
      return @aleph_item_permissions
    end
    
    def build_coverage_string(volumes, years)
      rv = ""
      rv += "VOLUMES: "+ volumes unless volumes.nil? or volumes.empty?
      rv += " (YEARS: "+ years+ ") " unless years.nil? or years.empty?
      return rv
    end
  end
end
