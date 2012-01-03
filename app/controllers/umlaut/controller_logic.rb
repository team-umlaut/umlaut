# Some standard logic needed accross Umlaut controllers, 
# module included in UmlautController superclass so it'll be avail
# to all controllers. Also exposes most of these methods as helpers so
# they'll be avail in views as well as controllers. 
module Umlaut::ControllerLogic
  extend ActiveSupport::Concern
  
  included do
    helper_method :escape_xml, :url_for_with_co, :current_permalink_url, :with_format
  end
  
  protected
  
  # Just replaces <, >, &, ', and " so you can include arbitrary text
  # as an xml payload. I think those three chars are all you need for
  # an xml escape. Weird this isn't built into Rails, huh?
  def escape_xml(string)    
    string.gsub(/[&<>\'\"]/) do | match |
     case match
       when '&' then '&amp;'
       when '<' then '&lt;'
       when '>' then '&gt;'
       when '"' then '&quot;'
       when "'" then '&apos;'
     end
    end   
  end
    
  # Pass in a hash of Rails params, plus a context object.
  # Get back a url suitable for calling those params in your
  # rails app, with the kev OpenURL context object tacked on
  # the end. This is neccesary instead of the naive hash
  # merge approach we were previously using, because
  # of possibility of multiple openurl kev query params
  # with same name.
  def url_for_with_co(params, context_object)
    url = url_for(params)
    if (url.include?('?'))
      url += '&'
    else
      url += '?'
    end
              
    url += context_object.kev   

    return url
  end
  
  # if it's an xml-http-request, and we're redirecting to ourselves...
  # afraid we're going to lost the X-Requested-With header on redirect,
  # messing up our Rails code. Add it as a query param, sorry weird
  # workaround.
  def params_preserve_xhr(my_params = params)
    if request.xml_http_request?                  
        my_params = my_params.clone
        my_params["X-Requested-With"] = "XmlHttpRequest"
    end
    my_params
  end
  
  
  # helper method we need available in controllers too
  # Absolute URL for permalink for given request.
  # Have to supply rails request and umlaut request.  
  def current_permalink_url(rails_request=request, umlaut_request=@user_request, options = {})
    # if we don't have everything, we can't make a permalink. 
    unless (umlaut_request && umlaut_request.referent &&
            umlaut_request.referent.permalinks &&
            umlaut_request.referent.permalinks[0] )

            return nil
    end
    
    return url_for(options.merge({:controller=>"store",    
        :id=>umlaut_request.referent.permalinks[0].id,
    :only_path => false}) )
        
  end
  
  # Let you render templates or partials in a different format
  # than current request format. 
  #     with_format("xml") do
  #        render 
  #     end
  def with_format(format, &block)
    old_formats = formats
    begin
      self.formats = [format]
      return block.call
    ensure
      self.formats = old_formats
    end
  end
  
  
end
