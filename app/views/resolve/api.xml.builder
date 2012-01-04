xml.instruct!
xml.umlaut do

  xml.request_id(  @user_request.id )
  
  xml.context_object_xml do
    xml << @user_request.referent.to_context_object.xml
  end

  xml << render(:partial=> "api_in_progress", :layout => false)
  
  xml.service_statuses do 
    @user_request.dispatched_services.each do | dispatched |
      xml.service(:id => dispatched.service_id ) do
        xml.class_name( dispatched.service.class )
        xml.display_name( dispatched.service.display_name )
        xml.created_at( dispatched.created_at )
        xml.status( dispatched.status )
        xml.exception_info do         
          if dispatched.exception_info 
            xml.class_name( dispatched.exception_info[:"class_name"] )
            xml.message( dispatched.exception_info[:message] )
          end
        end
        xml.service_types_generated do         
          dispatched.service.service_types_generated.each do |type|
            xml.name(type.name )
          end
        end
      end
    end
  end

  xml.responses do   
    @user_request.service_responses.collect {|response| response.service_type_value}.uniq.each do | type |
      xml.type_group(:name => type.name ) do      
        xml.display_name( type.display_name )
        xml.display_name_plural(type.display_name_pluralize) 
        xml.complete(! @user_request.service_type_in_progress?(type) ) 
        
        @user_request.get_service_type( type ).each do |response| 
          xml.response( :id => response.id ) do
            
            xml.service( response.service.service_id )
            xml.comment!("Attributes really vary depending on particular service, this makes it kind of tricky to deal with in an API. See documentation in ServiceResponse for conventions. Reccommend that you use umlaut_passthrough_url for url. Final destination url isis calculated on-demand by umlaut.") 
            ["display_text", "url", "notes"].each do |att|
              xml.tag!(att, response.attributes[att])
            end
            
            response.service_data.keys.each do |key|       
              value = response.service_data[key]
              # If it's a complex obj with a :to_xml, like a hash, use it. 
              if value.respond_to?(:to_xml)
                xml.tag!(key) do
                  xml << value.to_xml(:root => "records", :skip_instruct => true)
                end
              else
                xml.tag!(key, value.to_s.strip)
              end              
            end
            
            xml.umlaut_passthrough_url(url_for(:controller=>'link_router', :action => "index", :id=>response.id, :only_path => false))                          
          end
        end
      end
    end
  end
end
