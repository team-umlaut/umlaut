class CiteseerClient  
  def make_interesting(link, context_object)
    unless context_object.referent.metadata.has_key?("atitle") and link[:title].downcase.match(context_object.referent.metadata["atitle"].downcase)
      return
    end
    if link[:title].match("^Citations:")
      return {:highlighted_link => {:type => "citeseer",
                :title => "View articles that cite this in CiteSeer",
                :url => link[:url]}}
    else        
      return {:fulltext_link => {:type => "",
                :display_text =>"CiteSeer",
                :url => link[:url],
                :source=>'CiteSeer',
                :source_id=>"oai:CiteSeerPSU:"+URI.parse(link[:url]).path.sub(/[^0-9]/, "").sub(/\.html/, "")
              },
              :oai_target => {:repository=>"citeseer",
                :identifier=>"oai:CiteSeerPSU:"+URI.parse(link[:url]).path.sub(/[^0-9]/, "").sub(/\.html/, "")}}
        
    end     
  end
end

class CiteseerOAIClient
  include OAIClient
  
  def do_request  
    return self.do_complex_request(self.get_metadata_formats)
  end  
  
  def parse_oai_citeseer_record(record, response)    
    REXML::XPath.each(record, "./metadata/cs:oai_citeseer/dc:relation", {"cs"=>'http://copper.ist.psu.edu/oai/oai_citeseer/', 'dc'=>'http://purl.org/dc/elements/1.1/'}) { | relation |    
      rel = relation.get_text.value      
      response = @client.get_record(:identifier=>rel, :metadata_prefix=>"oai_citeseer")
      co = OpenURL::ContextObject.new
      co.import_context_object(self.contextobject_from_dc_citeseer(rel.record.metadata))
      unless response.similar_items.has_key?(@identifier.to_sym)
        response.similar_items[@identifier.to_sym] = []
      end
      response.similar_items[@identifier.to_sym] << 
        { :context_object => co, :title => co.referent.metadata["title"]} 
      
    }
  end 

  def contextobject_from_oai_citeseer(metadata)
    co = OpenURL::ContextObject.new
    co.referent.set_format('journal')
    
    co.referent.set_metadata('genre', 'article')
    REXML::XPath.each(metadata, "./metadata/cs:oai_citeseer/dc:title", {"cs"=>'http://copper.ist.psu.edu/oai/oai_citeseer/', 'dc'=>'http://purl.org/dc/elements/1.1/'}) { | title | 
      co.referent.set_metadata('atitle', title.get_text.value)
    }
    author = REXML::XPath.first(metadata, "./metadata/cs:oai_citeseer/cs:author", {"cs_dc"=>'http://copper.ist.psu.edu/oai/oai_citeseer/'})
    if author
      co.referent.set_metadata('au', author.get_text.value)
    end
    date = REXML::XPath.first(metadata, "./metadata/cs:oai_citeseer/cs:pubyear", {"cs_dc"=>'http://copper.ist.psu.edu/oai/oai_citeseer/'})    
    if date
      unless date.get_text.value == "unknown"
        co.referent.set_metadata('date', date.get_text.value)
      end
    end
    return co
  end
end