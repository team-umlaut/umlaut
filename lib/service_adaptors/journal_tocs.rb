# Experimental. Checks JournalTocs to see if ToC is available, and
# if so puts a link on page to Umlaut's own JournalTocs-backed list
# of recent articles, with Umlaut redirect links.
#
# Only operates on citations that have ISSN's and appear to be title-level
# (not article-level)
#
# Need to register account and email with JournalTocs. (URLs to come) 
#
# 
# optional config:
#
#  [:service_type]  default :highlighted_link, but change to eg
#                   :table_of_contents to put the link in a diff section.
#                   we've sort of abandoned the table_of_contents section. 
class JournalTocs < Service
  include MetadataHelper
  
  def initialize(config)
    @display_name = "JournalTOCs"
    @credits = {
      "JournalTOCs" => "http://www.journaltocs.ac.uk/"
    }
    @service_type = :highlighted_link
    super
  end
    
  
  def service_types_generated
    [ ServiceTypeValue[@service_type] ]
  end
  
  def handle(request)
    issn = get_issn(request.referent)
    
    unless issn && request.title_level_citation?
      return request.dispatched(self, true)
    end
    
    fetcher = JournalTocsFetcher.new(issn)    
    
    if fetcher.count > 0
      request.add_service_response(
        :service => self,  
        :display_text => "Current Articles",
        :service_type_value => @service_type.to_s,
        :issn => issn
      )
    end
        
    return request.dispatched(self, true)
  end
  
  # Over-ride to generate self-pointing link to JournalTOCs action
  def response_url(service_response, submitted_params)
    issn = service_response.view_data[:issn]
    
    return {:controller => "journal_tocs", :action => "show", :issn => issn}    
  end
  
end
