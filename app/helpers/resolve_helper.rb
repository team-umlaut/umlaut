module ResolveHelper
  # some useful methods started out as helper methods, but now are in the
  # Request model. We delegate them for convenience and backwards compat.
  delegate :get_service_type, 
           :failed_service_dispatches, 
           :service_type_in_progress?, 
           :service_types_in_progress?, 
           :any_services_in_progress?, 
           :title_level_citation?, :to => :@user_request


  #backwards compat, should be called title_level_citation? delegated
  # to @user_request above, but some
  alias title_level_request? title_level_citation?

  # Will render an Umlaut HTML section. See SectionRenderer.
  # Argument can be:
  # 1. An already initialized SectionRenderer
  # 2. :id => X, will load Section description hash from the resolve_sections
  #    configuration, finding description hash with :div_id == X.
  # 3. A complete section description hash. Ordinarily only used when that
  #    complete hash was previously looked up from resolve_sections config.
  #
  # For documentation of possible values in the section descripton hash,
  # see SectionRenderer. 
  def render_section(arguments = {})
    presenter = (arguments.kind_of?( SectionRenderer )) ? 
      arguments : SectionRenderer.new(@user_request, arguments  )
    render(:partial => "section_display", :locals => {:presenter => presenter })
  end

  def app_name
    return umlaut_config.app_name
  end

  # size can be 'small', 'medium', or 'large.
  # returns a ServiceResponse  object, or nil. 
  def cover_image_response(size='medium')
    cover_images = get_service_type('cover_image')
    cover_images.each do |service_response|
      return service_response if service_response.service_data[:size] == size 
    end
    return nil
  end

  # 
  # Returns the citation 
  # 
  # Specifically returns a description list of citation elements.
  # 
  def citation(cite)
    return content_tag(:dl, :class => "dl-horizontal umlaut-citation") {
      citations = "".html_safe
      # Title
      citations << citation_element(cite[:title_label], cite[:title], "title")
      # Author
      citations << citation_element("Author", cite[:author]) if cite[:author]
      # Subtitle
      citations << citation_element(cite[:subtitle_label], cite[:subtitle], "subtitle") if cite[:subtitle]
      # ISSN
      citations << citation_element("ISSN", cite[:issn]) unless (cite[:issn].nil? or cite[:issn].empty?)
      # ISBN
      citations << citation_element("ISBN", cite[:isbn]) unless (cite[:isbn].nil? or cite[:isbn].empty?)
      # Publisher
      citations << citation_element("Publisher", cite[:pub]) unless (cite[:pub].nil? or cite[:pub].empty?)
      # Publishing info, etc.
      citations << citation_element("Published", date_format(cite[:date])) unless (cite[:date].nil? or cite[:date].empty?)
      citations << citation_element("Volume", cite[:volume]) unless (cite[:volume].nil? or cite[:volume].empty?)
      citations << citation_element("Issue", cite[:issue]) unless (cite[:issue].nil? or cite[:issue].empty?)
      citations << citation_element("Page", cite[:page]) unless (cite[:page].nil? or cite[:page].empty?)
      citations
    }
  end

  # 
  # Returns a citation element that consists of an element label and 
  # the citation element content (data?).
  # 
  # Specifically returns a description list pair
  #   <dt class="#{label} umlaut-citation-label">#{label}</dt>
  #   <dd class="#{label} umlaut-citation-content">#{content}</dd>
  # 
  def citation_element(label, contents, klass="")
    contents = [contents] if contents.is_a? String
    return (content_tag(:dt, "#{label}:", :class => [label.downcase, "umlaut-citation-label", klass]) + 
      (contents.collect { |content| 
        content_tag(:dd, content, :class => [label.downcase, "umlaut-citation-content", klass]) }).join.html_safe)
  end

  # Did this come from citation linker style entry?
  # We check the referrer. 
  def user_entered_citation?(uml_request)
    return false unless uml_request && uml_request.referrer_id
    id = uml_request.referrer_id
    return id == 'info:sid/sfxit.com:citation' || id == umlaut_config.lookup("rfr_ids.citation") || id == umlaut_config.lookup('rfr_ids.opensearch')
  end

  def display_not_found_warning?(uml_request)
    metadata = uml_request.referent.metadata
    display_manually_entered_typo_warning = umlaut_config.lookup!("entry_not_in_kb_warning", false)
    return (metadata['genre'] != 'book' && metadata['object_id'].blank? && user_entered_citation?(@user_request) && display_manually_entered_typo_warning) 
  end

  # Generate content in an expand-contract block, with a heading that
  # you can click on to show/hide it. Actual content in block.
  # Example, in view:
  #  <% expand_contract_section("My Content", "div_id_to_use") do %>
  #      this will be hidden and shown
  #  <% end %>
  def expand_contract_section(arg_heading, id, options={}, &block)      
    expanded = (params["umlaut.show_#{id}"] == "true") || options[:initial_expand] || false
    icon = content_tag(:i, nil, :class => ["umlaut-toggle"] << ( expanded ? "umlaut_icons-list-open" : "umlaut_icons-list-closed"))
    heading = content_tag(:span,( expanded ? "Hide " : "Show "), :class=>'expand_contract_action_label') + arg_heading
    link_params = params.merge('umlaut.request_id' => @user_request.id,
      "umlaut.show_#{id}" => (! expanded).to_s,
      # Need to zero out format-related params for when we're coming
      # from a partial html api request, so the link we generate
      # is not to format json/xml/etc.       
      :format => nil, 
      'umlaut.response_format' => nil,
      'umlaut.jsonp'=>nil,
      # In Rails3, an :anchor param will actually be used for #fragmentIdentifier
      # on end of url
      :anchor => "#{id}_toggle_link"
      )
    # Make sure a self-referencing link from partial_html_sections
    # really goes to full HTML view.
    link_params[:action] = "index" if link_params[:action] == "partial_html_sections"
    return content_tag(:div, :class => "expand_contract_section") do
      link_to(icon + heading, link_params, :id => "#{id}_toggle_link", :class => "expand_contract_toggle") + "\n" +
        content_tag(:div, :id => id, :class => "expand_contract_content", :style => ("display: none;" unless expanded), &block)
    end         
  end

  # If response has a :content key returns it -- and marks it html_safe
  # if response has a :content_html_safe == true key. 
  # returns false if no :content. 
  def response_content(service_response)
    content = service_response[:content]
    return false unless content
    content = content.html_safe if service_response[:content_html_safe] == true
    return content
  end

  # Code-generating helper to add a "More" link to a list, with a maximum
  # number of items to show before 'more'. AJAXy show, with unobtrusive
  # degredation when no javascript. 
  # Based on the idea here for a helper that takes a block. Uses
  # expand_contract_section for actual hidden overflow. Will split list
  # into two different <ul>'s, one before the cut and one after. Will generate
  # <ul> tags itself. 
  # http://blog.zmok.net/articles/2008/04/22/block-level-helpers-in-ruby-on-rails
  #
  # id:  id to use for HTML div for hidden part of list. Other ids
  #      will be based on this id too.
  # list: your list
  # limit: how many lines to show before cut off. Default 5. Note that
  #        at least two items will always be included in 'more'. If cutoff
  #        is 5 and your list is 5, all 5 will be shown. If cut-off is 5
  #        and list is 6, 4 items will be shown, with more. This is five
  #        total lines if the 'more' is considered a line. 
  # block: will be passed |item, index|, should generate html for that
  #           item in block.
  #
  # Example, in a view:
  # <% list_with_limit("div_id_for_list", list, :limit=>10) do |item, index| %>
  #     <li>Item Number: <%= index %>: <%= item.title %></li>
  # <% end %>
  def list_with_limit(id, list, options = {}, &block)
    # backwards compatible to when third argument was just a number
    # for limit. 
    options = {:limit => options} unless options.kind_of?(Hash)
    options[:limit] ||= 5
    return "" if list.empty?
    content = "".html_safe
    content <<
    content_tag(:ul, :class => options[:ul_class]) do
      list.slice(0, options[:limit]).enum_for(:each_with_index).collect do |item, index|
        yield(item, index)
      end.join(" \n    ").html_safe
    end    
    if (list.length > options[:limit])
      content << 
      expand_contract_section("#{list.length - options[:limit] } more", id) do
        content_tag(:ul, :class=>options[:ul_class]) do
          list.slice(options[:limit]..list.length-1).enum_for(:each_with_index).each do |item, index|
            yield(item, index + options[:limit])
          end.join(" \n    ").html_safe
        end
      end
    end
    return content
  end

  ## 
  # Methods to grab SectionRenderer definitions from config. Caching in
  # class-level variables. 
  #
  @@bg_update_sections = nil
  @@partial_update_sections = nil

  # Called by background updater to get a list of all sections configured
  # in application config parameter resolve_sections to be included in
  # background updates. 
  def bg_update_sections
    unless (@@bg_update_sections)
      @@bg_update_sections = umlaut_config.lookup!("resolve_sections", []).find_all do |section|
        section[:bg_update] != false
      end
    end
    @@bg_update_sections
  end

  # Called by partial_html_sections action to get a list of all sections
  # that should be included in the partial_html_sections api response. 
  def partial_html_sections
    unless (@@partial_update_sections)
      @@partial_update_sections = umlaut_config.lookup!("resolve_sections", []).find_all do |section|
        section[:partial_html_api] != false
      end
    end
    @@partial_update_sections
  end

  # Called by resolve/index view to find sections configured
  # in application config resolve_sections list for a specific
  # part of the page. :main, :sidebar, or :resource_info. 
  def html_sections(area)
    umlaut_config.lookup!("resolve_sections", []).find_all do |section|
      section[:html_area] == area
    end
  end

  def html_section_by_div_id(div_id)
    umlaut_config.lookup!("resolve_sections", []).find do |defn|
      defn[:div_id] == div_id
    end
  end
  
  def item_icon(section_id)
    sections_with_icons = ["fulltext", "audio", "excerpts"]
    content_tag(:i, nil) if sections_with_icons.include? section_id
  end
end