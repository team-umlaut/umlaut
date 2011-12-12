# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  # Over-ride to allow default forcing of urls with hostnames.
  # This is neccesary for our partial_html_sections service
  # to work properly. Just set @generate_url_with_host = true
  # in your controller, and urls will be generated with hostnames
  # for the remainder of that action. 
  def url_for(argument = {})    
    if @generate_urls_with_host
      case argument
      when Hash
        # Force only_path = false if not already set
        argument[:only_path] = false if argument[:only_path].nil?
        return super(argument)
      when String
        # We already have a straight string, if it looks relative, 
        # absolutize it. 
        if argument.starts_with?("/")
          return root_url.chomp("/") + argument
        else
          return super(argument)
        end
      when :back
        return super(argument)
      else 
        # polymorphic, we want to force polymorphic_url instead
        # of default polymorphic_path         
        return polymorphic_url(argument)
      end    
    else
      # @generate_urls_with_host not set, just super
      super(argument)
    end    
  end

  # over-ride path_to_image to generate complete urls with hostname and everything
  # if @generate_url_with_host is set. This makes image_tag generate
  # src with full url with host. See #url_for
  def path_to_image(source)
    path = super(source)
    if @generate_urls_with_host
      protocol =  request.protocol()
      path = protocol + request.host_with_port() + path
    end
    return path
  end
  # Rails2 uses 'path_to_image' instead, that's what we have to override,
  # we used to use image_path, so let's alias that too. 
  alias :image_path :path_to_image

  
  # We want stylesheets and javascripts to do the exact same thing,
  # magic of polymorphous super() makes it work:
  def path_to_stylesheet(source)
    path = super
    if @generate_urls_with_host    
      path = request.protocol() + request.host_with_port() + path
    end
    return path
  end

  def path_to_javascript(source)
    path = super
    if @generate_urls_with_host    
      path = request.protocol() + request.host_with_port() + path
    end
    return path
  end  

  
  # pass in an OpenURL::ContextObject, outputs a link.
  def resolver_link(context_object, params={})
    
    # Content of the link. 
    if ( umlaut_config.link_img_url && params[:text].blank? )
      link_content = image_tag(umlaut_config.link_img_url, :border=>0, :alt=>umlaut_config.app_name)
    elsif ! params[:text].blank?
      link_content = params[:text]
    else
      link_content = umlaut_config.app_name
    end

    # url of the link. 
    if ( params[:params])
      link_to_arg = params[:params]
    else
      link_params = {:controller=>'resolve'}
      link_params.merge!( params[:extra_params] ) if params[:extra_params]
      link_to_arg = url_for_with_co( link_params, context_object )      
    end
    
    link_to(link_content, link_to_arg , :target=>params[:target])
  end

  # formats dates sent in an OpenURL into a more human-friendly
  # format. Input Dates look like '20000304'. Can be just year, or just
  # year/month, or all. Not sure what this format
  # is officially called. Not sure if they can have dashes sometimes? 
  def date_format(date_string)      
    date_string =~ /(\d\d\d\d)\-?(\d\d)?\-?(\d\d)?/

    begin
      year, month, day_of_month = $1, $2, $3
  
      if ( month )                
        date = Date.civil(year.to_i, month.to_i)
        formatted_month = date.strftime('%b')
      end
      
      output = year
      output += ' ' + formatted_month if formatted_month
      output += ' ' + day_of_month if day_of_month && day_of_month.to_i != 0
  
      return output
    rescue
      return date_string
    end
  end

  # Takes a hash, converts it to a query string (without leading
  # ?, supply that yourself. Oddly, this does not already seem to be
  # built in. 
  def hash_to_querystring(hash, seperator='&')
    list = []
    hash.each do |key, value|
      if (value.kind_of?(Array))
        # value is never supposed to be an array, but sometimes it is
        # Because we aren't really dealing with openurls right. oh well.
        values = value
      else
        values = Array.new.push(value)
      end
      values.each do |value|        
        value = (value.blank?) ? '' : CGI.escape(value.to_s)
        key = CGI.escape(key)
      
        list << key + '=' + value
      end
    end
    return list.join(seperator)
  end

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
