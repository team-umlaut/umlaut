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
    if arguments.kind_of?( SectionRenderer )
      presenter = arguments
    else
      presenter = SectionRenderer.new(@user_request, arguments  )
    end
    
 
    render(:partial => "section_display",
           :locals => 
            {:presenter => presenter }   )
  end

  
  def app_name
    return AppConfig.param("app_name", 'Find It')
  end


  # size can be 'small', 'medium', or 'large.
  # returns a ServiceResponse  object, or nil. 
  def cover_image_response(size='medium')
    cover_images = get_service_type('cover_image')
    cover_images.each do |st|
      return st if st.service_response.service_data[:size] == size 
    end
    return nil
  end

  # pass in a ServiceType object, usually for fulltext.
  # Returns a string URL that will take the user directly to
  # that resource. No longer using umlaut redirect, look up
  # the direct url through umlaut mechanisms first.
  # If you want to log direct link clickthroughs, you need to
  # hook in here. 
  def direct_url_for(service_type)                 
    return calculate_url_for_response(service_type)                                   
  end

  # Used by banner menu pages. 
  # pass in a service_type object, get a link (<a>) to display it in a frameset
  # page. Takes account of known_frame_escapers to send them to a new non-framed
  # window.
  def frameset_link_to(service_type, url_params={})
    if ( known_frame_escaper?(service_type))
      link_to(service_type.view_data[:display_text],
              direct_url_for(service_type),
              'target'=>'_blank')
    else
      url = frameset_action_url( service_type, url_params )
      link_to(service_type.view_data[:display_text],
               url,
              'target'=> '_top')
    end
  end
  


  # Did this come from citation linker style entry?
  # We check the referrer. 
  def user_entered_citation?(uml_request)
    return false unless uml_request && uml_request.referrer
    
    id = uml_request.referrer.identifier
    return id == 'info:sid/sfxit.com:citation' || id == AppConfig.param('rfr_ids')[:citation] || id == AppConfig.param('rfr_ids')[:opensearch]
  end

  def display_not_found_warning?(uml_request)
    metadata = uml_request.referent.metadata
    display_manually_entered_typo_warning = AppConfig.param("display_manually_entered_typo_warning", true)
    
  
    return (metadata['genre'] != 'book' && metadata['object_id'].blank? && user_entered_citation?(@user_request) && display_manually_entered_typo_warning) ? true : false
  end


  # Generate content in an expand-contract block, with a heading that
  # you can click on to show/hide it. Actual content in block.
  # Example, in view:
  #  <% expand_contract_section("My Content", "div_id_to_use") do %>
  #      this will be hidden and shown
  #  <% end %>
  def expand_contract_section(arg_heading, id, options={}, &block)

    # ugh, when we call this inside another partial with block, we need to pass the block.binding that we can give to concat
    options[:out_binding] ||= block.binding 
    
    # Set up proper stuff for current state.  
    expanded = (params["umlaut.show_#{id}"] == "true") || options[:initial_expand] || false

    icon = image_tag( ( expanded ? "list_open.png" : "list_closed.png"),
                       :alt => "",
                       :class => "toggle_icon",
                       :border => "0")
    heading = content_tag(:span,( expanded ? "Hide " : "Show "), :class=>'expand_contract_action_label') + arg_heading
    initial_hide = ( expanded ? "" : "display: none;")
    fragment = "#{id}_toggle_link"


    
    concat('<div class="expand_contract_section">', options[:out_binding])

    action = params["action"]
    # Make sure a self-referencing link from partial_html_sections
    # really goes to full HTML view. 
    action = "index" if action == "partial_html_sections"
    
    concat( link_to( icon + heading, 
                    params.merge({'umlaut.request_id' => @user_request.id,
                      "umlaut.show_#{id}" => (! expanded).to_s,
                      :anchor => fragment, :action => action}),
                      :id => fragment,
                      :class => "expand_contract_toggle"), options[:out_binding])

    concat("<div id=\"#{id}\" class=\"expand_contract_content\" style=\"#{initial_hide}\">",options[:out_binding])      
    yield()      
    concat("</div><!--exc-->", options[:out_binding] )
    concat("</div><!--exc-->", options[:out_binding])
    
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

    return if list.empty?

    concat("<ul class=\"#{options[:ul_class]}\">", block.binding)

  
    list.each_index do |index|
      item = list[index]

      yield(item, index)
      
      break if list.length > options[:limit] && index >= options[:limit]-2  
    end
    
    if (list.length > options[:limit] )

      # passing out_binding in is neccesary for this partial with block
      # inside a partial with block, bah. 

      concat("</ul>", block.binding)

      expand_contract_section("#{list.length - options[:limit] + 1} more", id, :out_binding => block.binding) do

        concat("<ul class=\"#{options[:ul_class]}\">", block.binding)
        (options[:limit]-1).upto(list.length-1) do |index|
          item = list[index]
          yield(item, index)
        end
        concat("</ul>", block.binding)      
      end      
    else
      concat("</ul>", block.binding)
    end
  end


  def link_to_toggle_debug_info(name = "[D]", options = {})
    javascript = " $$('.debug_info').each( function(el) { el.toggle(); });"  
  
    return link_to_function(name, javascript, options)  
  end
    
  
  
end
