class Ieee < RelevantSite
  require 'cgi'
  def get_services(link, request)
    link_title = link[:title]
    link_title.gsub!(/\<\/?b\>/,'')    

    unless request.referent.metadata["atitle"] and link[:title].downcase.strip == request.referent.metadata["atitle"].downcase
      return
    end
    services = {}
    services[:fulltext] = {:source=>'IEEE', :source_id=>CGI.parse(URI.parse(link[:url]).query)["arnumber"][0], :display_text =>"IEEE Xplore"}                 
    return services
  end
end