class CitebaseClient  
  def make_interesting(link, context_object)
  
    unless context_object.referent.metadata.has_key?("atitle") and (link[:title].downcase.strip == "Citebase - "+context_object.referent.metadata["atitle"].downcase or link[:title].downcase.strip == context_object.referent.metadata["atitle"].downcase)
      return
    end
    interesting = {}
    interesting[:fulltext_link] = {:type => "", :source=>'Citebase', :source_id=>CGI.parse(URI.parse(link[:url]).query)["id"][0], :display_text =>"Citebase",:url => link[:url]}                 
    interesting[:oai_target] = {:repository=>"citebase", :identifier=>CGI.parse(URI.parse(link[:url]).query)["id"][0]}
    return interesting
  end
end

class CitebaseOAIClient
  include OAIClient
  def do_request
    return self.do_complex_request(self.get_metadata_formats)
  end
  
  def parse_openURL_record(record, response)
    
    REXML::XPath.each(record, "./metadata/oai_dc:dc/dc:relation", {"oai_dc"=>'http://www.openarchives.org/OAI/2.0/oai_dc/', 'dc'=>'http://purl.org/dc/elements/1.1/'}) { | relation |
        co = OpenURL::ContextObject.new
        co.import_kev(URI.parse(relation.get_text.value).query)
        
        if co.referent.metadata.has_key?("atitle")
            title = co.referent.metadata["atitle"]
        elsif  co.referent.metadata.has_key?("title")
            title = co.referent.metadata["title"]
        else
            next
        end
        unless response.similar_items.has_key?(@identifier.to_sym)
          response.similar_items[@identifier.to_sym] = []
        end

        response.similar_items[@identifier.to_sym] << 
        { :context_object => co, :title => co.referent.metadata["title"]}        
    }

  end  
end