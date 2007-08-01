# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  

  # pass in an OpenURL::ContextObject, outputs a link.
  def resolver_link(context_object)
    #,'http://sfx.galib.uga.edu/sfx_git1/sfx.gif'
    resolver_img_url = AppConfig.param('link_img_url');
    app_name = AppConfig.param('app_name', 'Find It')

    if ( resolver_img_url )
      link_content = image_tag(resolver_img_url, :border=>0, :alt=>app_name)
    else
      link_content = app_name
    end
    
    link_to(link_content, context_object.to_hash.merge(:controller=>'resolve'))
  end
end
