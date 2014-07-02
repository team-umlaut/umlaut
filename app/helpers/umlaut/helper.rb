# Rails view helpers needed accross Umlaut controllers are collected
# here. Generally UmlautController will call "helper Umlaut::Helper" to
# expose these to all umlaut controllers. 

module Umlaut::Helper
  include Umlaut::UrlGeneration
  include Umlaut::FooterHelper
  include Umlaut::HtmlHeadHelper
  
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
      link_params = {:controller=>'/resolve', :action => "index"}
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



  # Button for showing permalink, dynamically loaded
  # with js if neccesary. works with load_permalink.js
  def render_umlaut_permalink
    if @user_request 
      content_tag("div", :class => "umlaut-permalink") do
        render_umlaut_permalink_toggle + 
        render_umlaut_permalink_content
      end
    end
  end

  def render_umlaut_permalink_toggle    

    link_to({:action => "get_permalink", :"umlaut.request_id" => @user_request.id}, 
             :class => "umlaut-load-permalink btn btn-mini", 
             :data => {"umlaut-toggle-permalink"=>"true"}) do
        content_tag("i") + " #{t('umlaut.permalink.name')}"
    end
  end

  # Proper content area to be shown by umlaut_permalink_toggle,
  # and loaded with content AJAXy.
  def render_umlaut_permalink_content
    content_tag("div", 
        :id => "umlaut-permalink-container",
        :class=> "umlaut-permalink-container",  
        :style => "display: none;",
        :'data-loaded' => current_permalink_url.present? ) do
      content_tag("span", :class => "umlaut-permalink-content") do
        link_to(current_permalink_url, current_permalink_url) if current_permalink_url
      end
    end
  end

  # Create dropdown if we have multiple locales, link if just two
  def render_locale_selector
    num_locales = I18n.config.available_locales.size
    if num_locales > 2
      render_locale_dropdown
    elsif num_locales == 2
      render_locale_link
    end
  end

  # create a link for the non-active locale
  def render_locale_link
    locales = I18n.config.available_locales
    other_locale = (locales - [I18n.locale]).pop
    link_to t(:language_name, :locale => other_locale), params.merge(:'umlaut.locale' => other_locale)
  end

  # Create a dropdown with the current language at the top
  def render_locale_dropdown
    locale_options = Array.new
    #make sure the locales display with their titles
    I18n.config.available_locales.each do |loc|
      locale_options.push([t('language_name', :locale => loc), loc])
    end
    form_tag({controller: params[:controller], action: params[:action]}, {method: "get"} ) do
      #output select tag with language options, current language set to selected
      concat(select_tag('umlaut.locale'.to_sym, options_for_select(locale_options, I18n.locale), onchange: 'this.form.submit()'))
       # send the url params as hidden fields
       params.each do |param|
         unless param[0] == 'controller' || param[0] == 'action' || param[0] == 'umlaut.locale'
           concat(hidden_field_tag("#{param[0]}", "#{param[1]}"))
         end
       end
    end
  end

end
