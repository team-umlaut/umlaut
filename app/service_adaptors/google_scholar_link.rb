# Generates a LINK to search google scholar for the requested article.
# G.Scholar has no API, all we can do is link out. 
#
# Will only generate link for citations that appear article-level
# and have author and title. 
#
# You probably want to only execute if there is no found fulltext, by configuring
# in umlaut_services.yml with:
#
# preempted_by:
#   existing_type: fulltext
#
# It will only be preempted by fulltext created in earlier waves of service
# execution, service order 'priority' matters. 
#
# optional config: service_type, defaults to 'highlighted_link', but maybe
#                  you want it actually under 'fulltext' or something. 
class GoogleScholarLink < Service
  
  
  def initialize(config)
    @service_type = "highlighted_link"
    @display_name = "Google Scholar"
    
    super(config)
  end
  
  def service_types_generated
    [ServiceTypeValue[@service_type]]
  end
  
  
  def handle(request)
    return request.dispatched(self, true) unless should_link_out_to?(request)

    link = "http://scholar.google.com/scholar?q=#{CGI.escape construct_query(request)}"
    
    request.add_service_response(
      :service      => self,      
      :display_text => "Look for article on Google Scholar",
      :url          => link,
      :service_type_value => @service_type,
      :notes        => "This article <b>may</b> be available on the public web, look for links labelled <span class='gscholar_example'>[html]</span> or <span class='gscholar_example'>[pdf]</span>".html_safe
    )
    
    return request.dispatched(self, true)
  end
  
  
  def construct_query(request)
    metadata = request.referent.metadata
    
    title_query   = "allintitle: \"#{metadata["atitle"]}\""
      
    author_query  = (metadata["aulast"] || metadata["au"]).strip.split(/\s+|[[:punct:]]+/).
      reject {|term| term.length <= 3}.
      collect { |term| "author:#{term}" }.join(" ")
    
    "#{title_query} #{author_query}"
  end
  
  def should_link_out_to?(request)
    return false unless (! request.title_level_citation?)
    
    metadata = request.referent.metadata
    
    metadata["atitle"] && (metadata["au"] || metadata["aulast"])
    
  end
  
end
