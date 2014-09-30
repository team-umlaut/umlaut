# Rails view helpers for outputting standard Umlaut content included
# in html <head>. Generally a layout will call #render_umlaut_head_content
# to render all standard Umlaut <head> content in a future-compatible way.
module Umlaut::HtmlHeadHelper

  # usually called in layout, render a link tag with opensearch auto-discovery
  def render_opensearch_link
    tag("link", :rel => "search", :type => "application/opensearchdescription+xml",
        :title =>  umlaut_config.opensearch_short_name,
        :href => url_for(:controller=>'/open_search', :only_path=>false))
  end

  # used on non-js progress page, we need to refresh the page
  # if requested by presence of @meta_refresh_self ivar.
  # this method usually called in a layout.
  def render_meta_refresh
    (@meta_refresh_self) ?
      tag("meta", "http-equiv" => "refresh", "content" => @meta_refresh_self) : ""
  end

  # standard umlaut head content, may later include more
  # stuff, local/custom layouts should call this in HEAD
  # to get forwards-compatible umlaut standard head content
  def render_umlaut_head_content
    render_opensearch_link + render_meta_refresh
  end

  # String meant for use in <title>
  def umlaut_title_text
    umlaut_config.app_name + (@page_title ? " | #{@page_title}" : "")
  end
  
end