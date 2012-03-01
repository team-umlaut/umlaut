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

  
end
