# SruClient is used by the Opac service model to grab records from SRU servers
class SruClient  
  require 'sru'
  require 'xisbn'  
  include XISBN
  attr_reader :number_of_results, :results, :accuracy
  attr_accessor :record_schema, :start_record, :maximum_records
  def initialize(service, url)
    @client = SRU::Client.new(url)
    # set client defaults
    @start_record = 1
    @maximum_records = 5
    @record_schema = 'marcxml'
    @results = []
  end
  
  # Find records by passing a Referent model
  def search_by_referent(rft)      
    query_types = {
      'journal'=>[
        'construct_issn_query',
        'construct_isbn_query',
        'construct_conference_search'],
      'book'=>[
        'construct_isbn_query', 
        'construct_xisbn_query',
        'construct_title_author_search',
        'construct_conference_search'
        ]
      }    
    query_types[rft.format].each { | qry |       	       
      if query = self.send(qry, rft)                
        records = @client.search_retrieve(query, {:version=>'1.1', :recordSchema=>@record_schema,:recordPacking=>'xml', :startRecord=>@start_record, :maximumRecords=>@maximum_records})                

        @number_of_results = records.number_of_records
        records.each do | record |
          @results << record
        end
        return if @number_of_results > 0          
      end
    }   
  end

  # Create a CQL query string based on ISBN
  def construct_isbn_query(rft)
    metadata = rft.metadata
    return false unless metadata["isbn"]
    @accuracy = 5
    return "bath.isbn = "+metadata["isbn"].gsub(/[^0-9X]/,'')
  end
  
  # Create a CQL query string based on ISBNs
  # provided by OCLC's xISBN service  
  def construct_xisbn_query(rft)
    return false unless rft.metadata["isbn"]
    query = []      
    begin
      xisbn(rft.metadata["isbn"], :timeout=>2).each do | isbn|
        query.push("bath.isbn = "+isbn) unless isbn == rft.metadata["isbn"].gsub(/[^0-9X]/,'')          
      end
	  rescue TimeoutError, Errno::ECONNREFUSED
	  	return false
	  end
    return false if query.empty?
    @accuracy = 5
    return query.join(" or ")              
  end    
  
  # Create a CQL query string based on title and author
  def construct_title_author_search(rft)
    metadata = rft.metadata
    query = []
    if metadata["btitle"]
      query << 'dc.title = "'+metadata["btitle"]+'"'      
    elsif metadata["title"]
      query << 'dc.title = "'+metadata["title"]+'"'
    end
    if metadata["aulast"]
      author = metadata["aulast"]
      if metadata["aufirst"]
        author += ", "+metadata["aufirst"]
      elsif metadata["auinit1"]
        author += ", "+metadata["auinit1"]
      elsif metadata["auinit"]
        author += ", "+metadata["auinit"][0,1]
      end
      query << 'dc.author = "'+author+'"'
    end
    return false if query.length < 2   
    @accuracy = 3   
    return query.join(" and ")
  end    	
  
  # Construct a CQL query string based on 
  # ISSN or EISSN
  def construct_issn_query(rft)
    issn = rft.metadata["issn"]
    issn = rft.metadata["eissn"] unless issn
    return false unless issn
    issn = issn.insert(4, '-') unless issn[4,1] == "-"   
    @accuracy = 5   
    return "bath.issn = "+issn
  end  
  
  # Determine if a Referent is probably a conference
  # and construct a CQL query string based on it
  def construct_conference_search(rft)
    metadata = rft.metadata
    query = []
    title = ""
    if metadata["btitle"]
      title = metadata["btitle"]
    elsif metadata["jtitle"]
      title = metadata["jtitle"]       
    elsif metadata["title"]
      title = metadata["title"]
    end
    unless self.is_conference?(title, rft)      
      return false
    end    
    query << 'dc.title all "'+title.gsub(/[^A-z0-9\s]/, ' ')+'"'
      
    if metadata["volume"]
      query << 'bib.volume = '+metadata["volume"]
    elsif metadata["date"]
      query << 'dc.date = '+metadata["date"]
    end      
    if query.length < 2
      return false
    end  
    @accuracy = 4
    return query.join(" and ")
  end 

  # Checks the Referent's metadata to see if the request is explicitly
  # defined as a conference, otherwise check the title against the Keyword
  # model to see if any matches to conference (i.e. IEEE, SPIE, etc.)     
  def is_conference?(title, metadata)
    return true if metadata["genre"] == 'conference' or metadata["genre"] == 'proceeding'
      
    Keyword.find_all_by_keyword_type('conference').each do |k|      
      r = Regexp.new('\b'+k.term+'\b', true)
      return true if title.match(r)                
    end
    return false      
  end
  
  # Construct a CQL query string based on subject
  # headings     
  def construct_subject_search(subs, sub_ors=nil)
    qsubs = []
    qsubParts = []
    subs.each { |s|
      s.split("--").each { |part|
        qsubParts << 'dc.subject = "'+part+'"'
      }
      qsubs << "("+qsubParts.join(" and ")+")"
    }
    query = qsubs.join(" and ")
    if sub_ors.length > 0
      query += " or " + sub_ors.join(" or ")
    end 
    return query 
  end  
  
  # Given an array of bib numbers, will fetch the holdings as Holding objects
  def get_holdings(bib_numbers)		
  	@results = []
  	holdings_query = []
  	bib_numbers.each do | bib_num |
      holdings_query << 'rec.id = '+bib_num
  	end
  	holdings_query.each do |hquery |
      begin
        @client.search_retrieve(hquery, :recordSchema=>'opacxml',:recordPacking=>'xml', :startRecord=>1, :maximumRecords=>5).each do | record |            
	      bib_num = REXML::XPath.first(record, "./bibliographicRecord/marc:record/controlfield[@tag='001']", {"marc"=>"http://www.loc.gov/MARC21/slim"}).get_text.value        
          new_holding = true
          unless hld = self.search_holdings(bib_num)
            hld = Holding.new
            hld.identifier = bib_num
          else
            new_holding = false
          end
	      REXML::XPath.each(record, "./holdings/holding") do |holding| 
            if holding.elements["localLocation"]
              location = holding.elements["localLocation"].get_text.value
            else
              location = ""
            end 	
		    if holding.elements["nucCode"]
		      nuc_code = holding.elements["nucCode"].get_text.value
		    else
		      nuc_code = ""
		    end               
            unless loc = hld.find_location(location)
              loc = HoldingLocation.new
              loc.name = location
              loc.code = nuc_code
              hld.locations << loc
            end  
            item = HoldingItem.new                	
		    if holding.elements["callNumber"]
		      call_num = holding.elements["callNumber"].get_text.value
		    else
		      call_num = "Click for more information"
		    end  
		    item.call_number = call_num  		
		               	
		    REXML::XPath.each(holding, "./circulations/circulation") do | circ |
		      item.status_date = nil
		      if circ.elements["availableNow"].attributes["value"] == "1"
		        item.status = "Available"
				item.code = 1
		      else
		      	item.status = "Not Available  "
				item.code = 2
	            if circ.elements["availabilityDate"] and circ.elements["availabilityDate"].has_text?
	             item.status_date = circ.elements["availabilityDate"].get_text.value
	            end	         
		      end
	          if circ.elements["enumAndChron"] and circ.elements["enumAndChron"].has_text?
	          	item.enumeration = circ.elements["enumAndChron"].get_text.value
	          end		      
		      if circ.elements["itemId"]
		        item.identifier = circ.elements["itemId"].get_text.value
		      end
		    end
		    loc.items << item
		  end
		  @results << hld if new_holding
    	end
      rescue SRU::Exception
      end
  	end
  end
  
  def search_holdings(bib_id)
    @results.each do | holding |
      return holding if holding.identifier == bib_id
    end
    return nil
  end  
end