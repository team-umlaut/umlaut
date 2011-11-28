# FIXME This service is not working
# For starters it needs the method service_types_generated()

class Opac < Service
  attr_reader :record_attributes, :display_name

  # The Opac class has a few assumptions
  # * You have some sort of bib client to get MARC records from your OPAC
  # * This operates independently of holdings data
  # * If your client can supply holdings information, you have the methods:
  # - init_holdings_client
  # - get_holdings
  #
  # The Opac class should be extended with your local connection client and
  # not called directly.
  
  def handle(request)
    # It's unlikely that consortial catalogs allow borrowing
    # of journals, but this may need to pushed to a client class
    
    if request.referent.format == 'journal' and @consortial
      return request.dispatched(self, true)
    end  
    @record_attributes = {}
    self.search_bib_data(request)
    if self.respond_to?(:init_holdings_client)
      opac_client = self.init_holdings_client
      opac_client.get_holdings(@record_attributes.keys)  
      self.check_holdings(opac_client.results, request)    
    else
      self.add_link_to_opac(client,request)
    end
    return request.dispatched(self, true)    
  end
  
  # Searches the bibliographic database
  def search_bib_data(request)    
    client = self.init_bib_client
    client.search_by_referent(request.referent)
    self.collect_record_attributes(client, request)    
  end
  
  # The client is expected to respond to <b>results</b> and return
  # an array of MARC records.  Override this method (and parse_for_fulltext,
  # collect_subjects, and enhance_referent) if your client does not return 
  # MARC.
  def collect_record_attributes(client, request) 
    require 'marc'    
    client.results.each do | record |
      MARC::XMLReader.new(StringIO.new(record.to_s)).each do | rec |
        id = nil
        
        # Assumes your local control number to be defined in 001
        rec.find_all { | f| '001' === f.tag}.each do | bibnum |
          id = bibnum.value
          @record_attributes[id] = {}
        end 
        
        # Conferences have their own crazy logic
        if self.is_conference?(rec)
          @record_attributes[id][:conference] = true
        else
          @record_attributes[id][:conference] = false
        end
        self.parse_for_fulltext_links(rec, request)              
        self.enhance_referent(rec, request, client.accuracy)
      end    
    end
  end  
  
  # Searches the MARC record for 856 tags, checks to see
  # if they seem to be digital representations and, if so,
  # adds them as fulltext service types
  def parse_for_fulltext_links(marc, request)    
    eight_fifty_sixes = []    
    marc.find_all { | f| '856' === f.tag}.each do | link |
      eight_fifty_sixes << link
    end    
    eight_fifty_sixes.each do | link |
      next if link.indicator2.match(/[28]/)
      next if link['u'].match(/(sfx\.galib\.uga\.edu)|(findit\.library\.gatech\.edu)/)
      label = (link['z']||'Electronic Access')
      request.add_service_response(
        :service=>self,
        :key=>label,
        :value_string=>link['u'],
        :service_type_value => 'fulltext'
        )
    end 
  end   
  
  # The client should be able to return an array of holdings objects
  def check_holdings(holdings, request)      
    return if holdings.empty?
    # These need to moved to services.yml
    electronic_locations = ['INTERNET', 'NETLIBRARY', 'GALILEO']
    holdings.each do | holding | 
      @record_attributes[holding.identifier.to_s][:holdings] = holding
      holding.locations.each do | location |
        next if electronic_locations.index(location.code)
        location.items.each do | item |         
          if request.referent.format == 'journal' and request.referent.metadata["volume"] and @record_attributes[holding.identifier.to_s][:conference] == false
            copy_match = false
            if item.enumeration
              if vol_match = item.enumeration.match(/VOL [A-z0-9\-]*/) 
                vol = vol_match[0]                
                vol.sub!(/^VOL\s*/, '')
                 (svol, evol) = vol.split('-')
                if request.referent.metadata["volume"] == svol
                  copy_match = true
                elsif evol
                  if request.referent.metadata["volume"] == evol
                    copy_match = true
                  elsif request.referent.metadata["volume"].to_i > svol.to_i and request.referent.metadata["volume"].to_i < evol.to_i                    
                    copy_match = true
                  end
                end
              end
            end
            if copy_match == true
              request.add_service_response(:service=>self,:key=>holding.identifier.to_s,:value_string=>location.name,:value_alt_string=>item.call_number,:value_text=>item.status.to_s, :service_type_value => 'holding')         
              break
            end   	                            		
          else  
            request.add_service_response(:service=>self,:key=>holding.identifier.to_s,:value_string=>location.name,:value_alt_string=>item.call_number,:value_text=>item.status.to_s,:service_type_value=>'holding')
          end  	         			
        end
      end
    end         
  end   
  
  # Check the leader to determine if this is defined as a conference or proceeding
  # in the MARC
  def is_conference?(marc)
    # Check the leader/008 for books and serials
    return true if marc['008'].value[29,1] == '1' && marc.leader[6,1].match(/[at]/) && marc.leader[7,1].match(/[abcdms]/)      
    # Check the leader/008 for scores and recordings
    return true if marc['008'].value[30,2] == 'c' && marc.leader[6,1].match(/[cdij]/) && marc.leader[7,1].match(/[abcdms]/)
    # Loop through the 006s
    marc.find_all {|f| ('006') === f.tag}.each { | fxd_fld |
      return true if fxd_fld.value[12,1] == '1' && fxd_fld.value[0,1].match(/[ats]{1}/)
      return true if fxd_fld.value[13,2]== 'c' && fxd_fld.value[0,1].match(/[cdij]{1}/)
    }      
    return false  
  end 
  

  # Determines the kind of record referred to in the MARC leader/fixed fields
  # (Book, Serial, Map, etc.)
  def record_type(marc)
    type = marc.leader[6,1]
    blvl = marc.leader[7,1]
    valid_types = ['a','t','g','k','r','o','p','e','f','c','d','i','j','m']
    rec_types = {
      'BKS' => { :type => /[at]{1}/,	:blvl => /[acdm]{1}/ },
      'SER' => { :type => /[a]{1}/,	:blvl => /[bs]{1}/ },
      'VIS' => { :type => /[gkro]{1}/,	:blvl => /[abcdms]{1}/ },
      'MIX' => { :type => /[p]{1}/,	:blvl => /[cd]{1}/ },
      'MAP' => { :type => /[ef]{1}/,	:blvl => /[abcdms]{1}/ },
      'SCO' => { :type => /[cd]{1}/,	:blvl => /[abcdms]{1}/ },
      'REC' => { :type => /[ij]{1}/,	:blvl => /[abcdms]{1}/ },
      'COM' => { :type => /[m]{1}/,	:blvl => /[abcdms]{1}/ }
    } 
    
    rec_types.each_key do | rec_type |
      return rec_type if type.match(rec_types[rec_type][:type]) and blvl.match(rec_types[rec_type][:blvl])
    end 
  end  
  
  # When given a ServiceResponse object as its argument, returns the anchor text and URL
  def to_fulltext(response)
    return {:display_text=>response.response_key, :url=>response.value_string}
  end
  
  # When given a ServiceResponse object as its argument, returns the object as a hash
  # with the keys:
  # - :display_text
  # - :call_number
  # - :status
  # - :source_name (which equates to self.display_name)
  def to_holding(response)
    return {:display_text=>response.value_string,:call_number=>response.value_alt_string,:status=>response.value_text,:source_name=>self.display_name}
  end 
  
  
  
  # When given a MARC record, this method fills in any missing
  # pieces of the Request.referent.  'accuracy' is a 3 point scale
  # determined by the client, 1 = 'possibly the correct resource', 2 = 
  # same resource, but not necessarily the same edition, 3 = exactly the 
  # same resource
  def enhance_referent(marc, request, accuracy)
    return unless accuracy > 2
    
    title_key = case request.referent.format
    when "book" then "btitle"
    when "journal" then "jtitle"
    when "dissertation" then "title"
    end
    metadata = request.referent.metadata
    unless metadata[title_key]
      if request.referent.metadata["title"] && title_key != "title"
        request.referent.enhance_referent(title_key, metadata["title"])
      else 
        request.referent.enhance_referent(title_key, marc['245'].value)
      end
    end
    unless metadata["au"]
      if marc['100'] && marc['100']['a']
        request.referent.enhance_referent('au', marc['100']['a'])
      end
    end
    unless metadata["aucorp"]
      if marc['110'] && marc['110']['a']
        request.referent.enhance_referent('aucorp', marc['110']['a'])
      end      
    end
    return unless accuracy > 3    
    unless metadata["place"]
      if marc['260'] && marc['260']['a']
        request.referent.enhance_referent('place', marc['260']['a'])
      end       
    end     
    unless metadata["pub"]
      if marc['260'] && marc['260']['b']
        request.referent.enhance_referent('pub', marc['260']['b'])
      end       
    end  
    unless metadata["edition"]  
      if marc['250'] && marc['250']['a']
        request.referent.enhance_referent('edition', marc['250']['a'])
      end       
    end 
    unless metadata["series"]
      if marc['490'] && marc['490']['a']
        request.referent.enhance_referent('series', marc['490']['a'])
      elsif marc['730'] && marc['730']['a']
        request.referent.enhance_referent('series', marc['730']['a'])        
      end        
    end 
    unless metadata["date"] or request.referent.format == 'journal'
      if marc['260'] && marc['260']['c']
        request.referent.enhance_referent('date', marc['260']['c'])   
      end   
    end 
    unless request.referent.format
      type = self.record_type(marc)
      request.referent.enhance_referent('format', 'book', false) if type == "BKS"
      request.referent.enhance_referent('format', 'journal', false) if type == "SER"
    end    
    unless metadata["genre"]
      if self.is_conference?(marc)
        if metadata["atitle"]
          request.referent.enhance_referent('genre', 'proceeding')
        else
          request.referent.enhance_referent('genre', 'conference')
        end
      elsif type = self.nature_of_contents(marc)
        case type
        when "dissertation" then request.referent.enhance_referent('format', 'dissertation', false)            
        when "patent" then request.referent.enhance_referent('format', 'patent', false)
        when "report" then request.referent.enhance_referent('genre', 'report')
        end
      else
        type = self.record_type(marc)
        if type == "BKS"
          request.referent.enhance_referent('format', 'book', false) unless request.referent.format == 'book'
          if metadata["atitle"]
            request.referent.enhance_referent('genre', 'bookpart')
          else
            request.referent.enhance_referent('genre', 'book')
          end
        elsif type == "SER"
          request.referent.enhance_referent('format', 'journal', false) unless request.referent.format == 'journal'        
          if metadata["atitle"]
            request.referent.enhance_referent('genre', 'article')
          elsif metadata["issue"]
            request.referent.enhance_referent('genre', 'issue')
          else
            request.referent.enhance_referent('genre', 'journal')
          end
        end
      end
    end
    
    unless metadata["isbn"]
      if marc['020'] && marc['020']['a']
        request.referent.enhance_referent('isbn', marc['020']['a'])
      end
    end   
    unless metadata["issn"]
      if marc['022'] && marc['022']['a']
        request.referent.enhance_referent('issn', marc['022']['a'])
      end    
    end 
    unless metadata["sici"]
      if marc['024'] && marc['024'].indicator1 == "4"
        request.referent.enhance_referent('sici', marc['024']['a'])      
      end       
    end
    
    unless metadata["coden"]
      if marc['030'] && marc['030']['a']
        request.referent.enhance_referent('coden', marc['030']['a'])      
      end       
    end    
  end 
  
  # When given a MARC record, determines if the referent should be
  # defined as a dissertation, report or patent.
  def nature_of_contents(marc)
    types = {'m'=>'dissertation','t'=>'report','j'=>'patent'}
    idx = nil
    if self.record_type(marc) == 'BKS'
      idx = 24
      len = 4
    elsif self.record_type(marc) == 'SER'
      idx = 25
      len = 3
    end
    if idx
      marc['008'].value[idx,len].split(//).each do | char | 
        return types[char] if types.keys.index(char)
      end
    end
    marc.find_all {|f| ('006') === f.tag}.each do | fxd_fld |
      idx = nil
      if fxd_fld.value[0,1].match(/[at]{1}/)
        idx = 7
        len = 4
      elsif fxd_fld.value[0,1].match('s')
        idx = 8
        len = 3
      end     
      if idx 
        fxd_fld.value[idx,len].split(//).each do | char | 
          return types[char] if types.keys.index(char)
        end
      end  
    end        
    return false      
  end    
  
  # Builds a URL either based on a URL in the value_string or builds a link to the 
  # OPAC using the direct_link_arg and the bib ID.
  def response_url(service_type, http_params)
    response service_type.service_response
    return CGI.unescapeHTML(response.value_string) if response.value_string.match(/^http(s)?:\/\//)
    return @url+'&'+@direct_link_arg+response.response_key          
  end
end
