# Some rails view helpers useful for debugging links, and rendering credits
# in footer. 
module Umlaut::FooterHelper
  
  # Renders list of external services used by currently configured Umlaut, 
  # with URLs. In some cases ToS of third party services may require this.
  # Gets list from "credits" config in Service plugins. 
  # Requires @collection ivar in controller holding an umlaut Collection
  # object, as there will be in ResolveController. 
  def render_service_credits
    if @collection
      content = "".html_safe
            
      content << "Powered by ".html_safe + link_to("Umlaut", "http://github.com/team_umlaut/umlaut") + ". ".html_safe
      
      credit_segments = []
      
      services = @collection.instantiate_services!
      
      # put em all in one hash to eliminate exact-name dups
      credits = {}
      services.each {|s|  credits.merge! s.credits } 
      
      credits.keys.sort.each do |name|
        if credits[name].blank?
          credit_segments << html_escape(name)
        else
          credit_segments << link_to(name, credits[name])
        end
      end
      
      
      if credit_segments.length > 0
        content << "Using services from ".html_safe
        content << credit_segments.join(", ").html_safe
        content << " and others.".html_safe
      end
      
      return content
    end
  end
  
  # tiny [S] link directly to SFX, in footer. For debugging.
  # Only if sfx.sfx_base_url is configured. 
  def link_to_direct_sfx
    if (base = umlaut_config.lookup!("sfx.sfx_base_url")) && @user_request
      url = base.chomp("?") + "?"
      url += @user_request.to_context_object.kev
      url += "&sfx.ignore_date_threshold=1" if respond_to?(:title_level_request) && title_level_request?
      
      link_to "[S]", url
    end
  end
  
  # If you have a config.test_resolve_base configured,
  # will output a [T] link, usually for footer, for staff
  # debugging. 
  def link_to_test_resolve
    if (test_base = umlaut_config.lookup!("test_resolve_base")) && @user_request
      link_to "[T]", test_base.chomp("?") + "?" + @user_request.to_context_object.kev
    end
  end

end
