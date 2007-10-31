# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper


  # pass in an OpenURL::ContextObject, outputs a link.
  def resolver_link(context_object, params={})
    #,'http://sfx.galib.uga.edu/sfx_git1/sfx.gif'
    resolver_img_url = AppConfig.param('link_img_url');
    app_name = AppConfig.param('app_name', 'Find It')

    if ( resolver_img_url && params[:text].blank? )
      link_content = image_tag(resolver_img_url, :border=>0, :alt=>app_name)
    elsif ! params[:text].blank?
      link_content = params[:text]
    else
      link_content = app_name
    end

    if ( params[:params])
      link_params = params[:params]
    else
      link_params = context_object.to_hash.merge(:controller=>'resolve')
      link_params.merge!( params[:extra_params]) unless params[:extra_params].blank?
      end
    
    link_to(link_content, link_params, :target=>params[:target])
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
      value = (value.blank?) ? '' : CGI.escape(value)
      key = CGI.escape(key)
    
      list << key + '=' + value
    end
    return list.join(seperator)
  end

  # Absolute URL for permalink for given request.
  # Have to supply rails request and umlaut request.
  def permalink_url(rails_request, umlaut_request)
    
    shortcut = rails_request.protocol
    shortcut += rails_request.host_with_port
    shortcut += url_for :controller=>"store", :id=>umlaut_request.referent.permalinks[0].id
    
    return shortcut
  end

  # Did this come from citation linker style entry?
  # We check the referrer. 
  def user_entered_citation?(uml_request)
     id = uml_request.referrer.identifier
     return id == 'info:sid/sfxit.com:citation' || id == 'info:sid/umlaut.code4lib.org:citation'
  end    
  
end
