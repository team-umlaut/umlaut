#!/usr/bin/ruby


require 'net/http'
require 'rexml/document'


#  Hip3 Module has been written for JHU's HIP3 installation. It may not work
# quite right with other installations, I'm almost certain it needs to be
# abstracted and parameterized better to be more generic.
module Hip3


	# Right now this only searches by ISSN.
  # If multiple search criteria are supplied, will 'or' them all to find
  # bibs matching ANY criteria. 
  # keywords should be an array, and will be 'and'ed
	# Searches using the HIP3 xml 'interface', which means it may be sensitive to
	# HIP display changes that change XML. 
	# It finds BibNums, and creates Hip3Bib
	# objects based on that bibNum. Doesn't take any other info but Bib num from
	# the actual search response, but it could, and pre-load the bib object.	
	class BibSearcher
    ISSN_KW_INDEX = '.IS'
    ISBN_KW_INDEX = '.IB' 

    GEN_KW_INDEX = '.GW'
    TITLE_KW_INDEX = '.TW'
    SERIAL_TITLE_KW_INDEX = '.ST'
    AUTHOR_KW_INDEX = '.AW'

    BIBNUM_INDEX = 'BIB'

    SUDOC_KW_INDEX = '.SD'
    
		attr_accessor :httpSession 
		attr_accessor :hip_base_url_str, :hip_base_url
		attr_reader :issn, :isbn # writers provided concretely
    attr_accessor :sudoc, :bibnum
    attr_reader :keywords
		
		# You can pass in a Net::HTTP, if you'd for instance like to keep
    # open a persistent connection. You are advised to use our special 
    # Hip3::HTTPSession, for it's error handling. Or better yet, just
    # leave second argument empty, and we'll create one for you. 
		def initialize(arg_base_path, arg_http_session=nil)      
      self.hip_base_url_str = arg_base_path
      self.hip_base_url = URI::parse(self.hip_base_url_str);
      
      
			self.httpSession = arg_http_session
      if self.httpSession.nil?
        self.httpSession = Hip3::HTTPSession.create(self.hip_base_url.host() )
      end
      
      self.keywords = []
			
		end


    
		# Method checks for basic well-formedness (doesn't actually check
    # checksum), and adds hyphen if neccesary, because our HIP needs
		# it to search. Bah! 
		def issn=(argIssn)
			if (argIssn.nil? || argIssn.empty?)
				@issn = nil
				return
			end
			
			# first remove hyphen to normalize
			argIssn.gsub!('-', '')
			# now check for basic well-formedness
			unless argIssn =~ /\d{7}(\d|X)/ 
				raise ArgumentError.new("Malformed issn: #{argIssn}") 
			end
			#now put the hyphen back, sadly
			@issn = argIssn.slice(0..3) + '-' + argIssn.slice(4..7)			
		end

    def isbn=(arg_isbn)
      if ( arg_isbn.nil? || arg_isbn.empty? )
        @isbn = nil
      end
      
      @isbn = arg_isbn
    end

    # Yet another way to specify search criteria.
    # Hash, where the key is the name of a HIP keyword Index (use
    # constants in this class if possible), and the value is an array of
    # keywords. Everything is "anded" together. 
    def search_hash=(hash)
      @search_hash = hash
    end
    
    def keywords=(arg_kw)
      set_keywords(arg_kw)
    end
    
    def set_keywords(arg_kw, args={})

      arg_kw = [] if arg_kw.nil?
      args[:index] = :general unless args[:index]

      @keywords = arg_kw


      
      if (args[:index] == :title)
        @keyword_index = TITLE_KW_INDEX
      elsif (args[:index] == :serial_title)
        @keyword_index = SERIAL_TITLE_KW_INDEX
      else
        @keyword_index = GEN_KW_INDEX
      end
    end

    # Returns the URL starting from / that specifies the search criteria to
    # HIP. 
		def searchPath(args = {})
      args[:xml] = true if args[:xml].nil?
      
			path = self.hip_base_url.path() + '?' 			"menu=search&aspect=power&npp=30&ipp=20&spp=20&profile=general&ri=2&source=%7E%21horizon"

      criteria = Array.new

      # Need to do search_hash first, to make sure bibnum and isbn search
      # come LAST, for HIP. 
      unless ( @search_hash.blank?)
        manual_criteria = []
        @search_hash.each_pair do |index, kws|
         manual_criteria << kws.collect do |kw|
             kw = '"' + kw + '"' unless [BIBNUM_INDEX, ISSN_KW_INDEX, ISBN_KW_INDEX].include?(index)
            "&index=#{index}&term=#{URI.escape(kw)}"
          end
        end
        path << manual_criteria.join("&oper=and") << "&oper=or"
      end

      
      criteria<< "&index=#{SUDOC_KW_INDEX}&term=#{URI.escape('"' + self.sudoc + '"' )}" unless sudoc.nil?
      criteria << "&index=#{ISSN_KW_INDEX}&term=#{URI.escape(self.issn)}" unless issn.nil?
      # For some reason ISBN must be LAST in order, and bibnum must be right before, or HIP doesn't like it.
      criteria << "&index=#{BIBNUM_INDEX}&term=#{URI.escape(self.bibnum)}" unless bibnum.blank?
      # Go figure. I hate you, HIP. 
      criteria << "&index=#{ISBN_KW_INDEX}&term=#{URI.escape(self.isbn)}" unless isbn.nil?
      
      criteria << keyword_url_args
      path << criteria.join("&oper=or")



      
      path << "&x=0&y=0&aspect=power"
      path << "&GetXML=1" if args[:xml]

      return path

		end
    
    def keyword_url_args
      args =
      self.keywords.collect { |k| "&index=#{@keyword_index}&term=#{CGI.escape('"' + k + '"')}" }

      return args.join("&oper=and") || ""            
    end

    # returns the numbef of hits--does not cache anything, calling
    # this method will cause a trip to the db, and calling search
    # will cause another one. 
    def count
      return [] if insufficient_query

      httpResp = httpSession.get( searchPath, nil )
      reDoc = REXML::Document.new( httpResp.body )

      # Confusingly, sometimes
			# this gives us a search results page, and sometimes it gives us
			# a single bib
    
      # single bib?
      if ( reDoc.elements['searchresponse/fullnonmarc/searchresults/results/row/key'])
        return 1
      end

      # Multiple, get the count
      hits = reDoc.elements['searchresponse/yoursearch/hits']
      return hits ? hits.get_text.to_s.to_i : 0       
    end
    
		# Returns an array of bib objects. 
		def search
      return [] if insufficient_query
			httpResp = httpSession.get(searchPath(), nil )
		
			reDoc = REXML::Document.new( httpResp.body )
		
			# Confusingly, sometimes
			# this gives us a search results page, and sometimes it gives us
			# a single bib

			# single bib?
			if ( bibNum = reDoc.elements['searchresponse/fullnonmarc/searchresults/results/row/key'])
				# Single bib
				#return [Hip3::Bib.new( httpSession, bibNum.text, reDoc)]
        return [Hip3::Bib.new( bibNum.text, self.hip_base_url,
                               :http_session => httpSession,
                               :bib_xml_doc => reDoc
                               )]
			end

			
			# Multi-response
			# Get Bib #s and titles for each result.
      
			bib_summaries =  reDoc.elements.to_a('searchresponse/summary/searchresults/results/row/');

      return bib_summaries.collect do |bib_xml|
        next unless bib_xml.elements['key']

        # Find a title from the summary xml
        title_el = bib_xml.elements['TITLE/data/text']
        title = title_el ? title_el.text : nil
        # remove possible author on there, after a '/' char. That's how HIP rolls. 
        title.sub!(/\/.*$/, '')
        
        Hip3::Bib.new(bib_xml.elements['key'].text, self.hip_base_url, :http_session => httpSession, :title => title )
      end
      

      #return bibNums.collect{ |bibNum| Hip3::Bib.new( bibNum, self.hip_base_url, :http_session => httpSession) }
		end

    def insufficient_query
      # Have to have some search criteria to search
      return (self.issn.nil? && self.isbn.nil? && self.sudoc.blank? && self.keywords.blank? && @search_hash.blank?)
    end

    def search_url
      return self.hip_base_url_str + '?' + self.searchPath(:xml => false )
    end
    
	end

	
	class HTTPSession < Net::HTTP
		
		def HTTPSession.create(a_host, a_port = 80)
			HTTPSession.new(a_host, a_port)
		end

		
		def get(path, headers=nil, &block)
			#ta = Time.new
			response = super(path, headers, block)
			#duration = Time.new - ta
			#puts "Duration: #{duration}"
			#$time_in_http += duration
			
			#This method raises if not 2xx response status.
			#No idea why such a method is called 'value'
			response.value
			
			return response
		end

    # Does a get whether or not the connection is already open,
    # if it wasn't already open, will make sure to leave it closed again. 
    def self.safe_get(httpObj, path, headers=nil)
        if httpObj.started?
          return httpObj.get(path, headers)
        else
          # With a block, will close the connection when we're done. 
          return httpObj.start { |h| h.get(path, headers) }
        end
    end
    
	end
	

	
end 

	









