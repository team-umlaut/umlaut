#encoding: UTF-8

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

  # Return an array of css classes that should be attached to an .umlaut_section
  # generally 'umlaut-section', plus the section_id, plus possibly 
  # 'umlaut-section-highlighted'. See #should_highlight_section?
  #
  # pass in:
  # * current Umlaut Request object
  # * string section id
  # * array of umlaut ServiceResponses already fetched for this section. 
  def section_css_classes(umlaut_request, section_id, response_list)
    classes = ["umlaut-section", section_id]
    classes << 'umlaut-section-highlighted' if should_highlight_section?(umlaut_request, section_id, response_list)
    return classes
  end

  # Called by #section_css_classes. Decides if a section should get
  # highlight styles. Default logic highlights fulltext if present,
  # otherwise holdings/docdel sections (in some cases both even if holdings present,
  # in some cases just docdel, depending on nature of resource.) This is
  # something local institutions may want to supply custom logic for,
  # over-ride this method. 
  #
  # This is VERY tricky to get right, BOTH becuase of local policy differences,
  # AND becuase umlaut's concurrent service handling means things are changing
  # all the time. Umlaut used to just highlight fulltext with responses, that's it.
  # But we're trying something more sophisticated. You may want to over-ride with
  # something simpler, or something better suited to local policies and conditions. 
  def should_highlight_section?(umlaut_request, section_id, response_list)
    case section_id
    when "fulltext"
      umlaut_request.get_service_type("fulltext").present?
    when "holding"
      umlaut_request.get_service_type("holding").present? && umlaut_request.get_service_type("fulltext").empty?
    when "document_delivery"
      # Only once fulltext and holdings are done being fetched. 
      # If there's no fulltext or holdings, OR there's holdings, but
      # it's a journal type thing, where we probably don't know if the
      # particular volume/issue wanted is present. 
      umlaut_request.get_service_type("fulltext").empty? && 
      (! umlaut_request.service_types_in_progress?(["fulltext", "holding"])) && (
        umlaut_request.get_service_type("holding").empty? || 
        umlaut_request.referent.format == "journal"
      )
    end
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
    icon = content_tag(:i, nil, :class => [] << ( expanded ? "umlaut_icons-list-open" : "umlaut_icons-list-closed"))
    heading = content_tag(:span,( expanded ? "Hide " : "Show "), :class=>'expand_contract_action_label') + arg_heading
    body_class = (expanded ? "in" : "")
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
    return content_tag(:div, :class => "collapsible", :id => "collapse_#{id}") do
      link_to(icon + " " + heading, link_params, :class => "collapse-toggle", "data-target" => "##{id}", "data-toggle" => "collapse") +
        content_tag(:div, :id => id, :class => ["collapse"]<< body_class, &block)
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
    options[:ul_class] ||= "list-unstyled"
    return "" if list.empty?
    visible_list  = (list.length > options[:limit]) ? list.slice(0, options[:limit]-1) : list
    hidden_list   = (list.length > options[:limit]) ? list.slice((options[:limit]-1)..list.length-1) : []
    parts =[]
    parts << content_tag(:ul, :class => options[:ul_class]) do
      safe_join(
        visible_list.enum_for(:each_with_index).collect do |item, index|
          yield(item, index)
        end, " \n    "
      )
    end
    if (hidden_list.present?)
      parts << expand_contract_section("#{hidden_list.length} more", id) do
        content_tag(:ul, :class=>options[:ul_class]) do
          safe_join(
            hidden_list.enum_for(:each_with_index).collect do |item, index|
              yield(item, index + options[:limit] - 1)
            end, " \n    "
          )
        end
      end
    end
    return safe_join(parts, "\n")
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

  ##
  # Outputs "yyyy - yyyy" coverage summary, with html tags, IF coverage
  # dates are available, it is a title-level request, and we're configured
  # to show with config resolve_display.show_coverage_summary
  def coverage_summary(response)
    unless (@user_request.title_level_citation? &&
            umlaut_config.lookup!("resolve_display.show_coverage_summary", false) &&
            (response[:coverage_begin_date] || response[:coverage_end_date]))
      return nil
    end

    start   = response[:coverage_begin_date].try(:year) || I18n.t("umlaut.coverage_summary.open_start")
    finish  = response[:coverage_end_date].try(:year) || I18n.t("umlaut.coverage_summary.open_end")

    content_tag("span", :class=>"coverage_summary") do
      "#{start} – #{finish}:"
    end
  end
end
