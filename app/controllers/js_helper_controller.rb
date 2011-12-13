# Controller that just has one helper action for external sites using
# our Javascript HTML updater stuff. 
class JsHelperController < UmlautController

  def loader
    @generate_urls_with_host = true
    render :template => "js_helper/loader.erb.js"
  end
  
end
