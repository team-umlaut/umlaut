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

  # over-ride image_path to generate complete urls with hostname and everything
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
  #alias :stylesheet_path :path_to_stylesheet
  def path_to_javascript(source)
    path = super
    if @generate_urls_with_host    
      path = request.protocol() + request.host_with_port() + path
    end
    return path
  end  
  #alias :javascript_path :path_to_javascript

  
  # pass in an OpenURL::ContextObject, outputs a link.
  def resolver_link(context_object, params={})
    #,'http://sfx.galib.uga.edu/sfx_git1/sfx.gif'
    resolver_img_url = AppConfig.param('link_img_url');
    app_name = AppConfig.param('app_name', 'Find It')

    # Content of the link. 
    if ( resolver_img_url && params[:text].blank? )
      link_content = image_tag(resolver_img_url, :border=>0, :alt=>app_name)
    elsif ! params[:text].blank?
      link_content = params[:text]
    else
      link_content = app_name
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

  ## Generate JS and sometimes CSS references neccesary to unobtrusively
  # add our JS behaviors to an Umlaut page. Options specify exactly what
  # to include. Options:
  # * :jquery
  # * :jquery_ui_js
  # * :jquery_ui_css
  # * :updater (js html updater for background content)
  # * :resolve_menu (behaviors for resolve menu)
  # * :title_search (behaviors for search pages)
  #
  # Or shortcut aliases, recommended in case the details change:
  # * :jquery_ui => :jquery_ui_js, :jquery_ui_css
  # * :resolve_complete => :jquery, :jquery_ui, :updater, :resolve_menu
  # * :search_complete => :jquery, :jquery_ui, :title_search
  #
  # Examples:
  # <%= render_javascript_behaviors(:resolve_complete) %>
  # <%= render_javascript_behaviors(:jquery, :jquery_ui, :title_search) %>
  def render_javascript_behaviors(*options)
    results = ""
    
    js_arguments = []
    css_arguments = []

    # magic combining options
    if ( options.delete(:resolve_complete))
      options << :jquery
      options << :jquery_ui
      options << :resolve_menu
    end
    if ( options.delete(:search_complete) )
      options << :jquery
      options << :jquery_ui
      options << :title_search
    end
    

    if options.include? :jquery
      js_arguments << "jquery/jquery-1.4.2.min.js"      
    end
    unless (options & [:jquery_ui, :jquery_ui_js]).blank?
      js_arguments << "jquery/jquery-ui-1.8.custom.min.js"      
    end
    unless (options & [:jquery_ui, :jquery_ui_css]).blank?
      css_arguments << "jquery-ui/jquery-ui-1.8.custom.css"
    end
    unless (options & [:updater, :resolve_menu ]).blank?
      js_arguments << "jquery/umlaut/update_html.js"
    end
    if options.include? :resolve_menu
      js_arguments.concat( [  
                  "jquery/umlaut/expand_contract_toggle.js",
                  "jquery/umlaut/simple_visible_toggle.js",
                  "jquery/umlaut/ajax_windows.js" ]  )
    end
    if options.include? :title_search
      js_arguments << "jquery/umlaut/search_autocomplete.js"
    end

    #cache_key = "cache/umlaut-" + options.collect{|a| a.to_s}.sort.join("-")    
    #js_arguments << {:cache => cache_key} unless js_arguments.empty?
    
    results << stylesheet_link_tag( *css_arguments ) unless css_arguments.empty?
    results << "\n"
    results << javascript_include_tag( *js_arguments  ) unless js_arguments.empty?
    results << "\n"
    results << javascript_tag("jQuery.noConflict();") if options.include?(:jquery)

    return results.html_safe
  end

  
  
  
end
