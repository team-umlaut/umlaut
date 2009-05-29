module ResolveHelper
  def load_custom_partial(action, view)
    begin
      render :partial=>action+'_'+view
     rescue ActionView::ActionViewError
      render :partial=>action+'_default'
     end
  end

  # Returns Array of ServiceType objects associated with current @user_request
  # (the Umlaut Request object), matching svc_type type. svc_type should be
  # a string name of ServiceTypeValue
  # delegates work to Request#get_service_type for the current request. 
  # Works on in-memory array fetched once per request, unless you pass
  # in :refresh=>true.  It's much more efficient to work in memory in this
  # case.   
  def get_service_type(svc_type, options = {})
    return @user_request.get_service_type(svc_type, options)          
  end

  # Returns an array of DispatchedServices that are marked failed. 
  def failed_service_dispatches
    return @user_request.failed_service_dispatches
  end

  # Are there background services queued or in progress that might
  # return the service type? Please pass in a ServiceTypeValue, or
  # a String if you must (but just convert with ServiceTypeValue["string"],
  # why not?
  def service_type_in_progress?(svc_type)
    return @user_request.service_type_in_progress?(svc_type)
  end
  def service_types_in_progress?(array)
    return @user_request.service_types_in_progress?(array)
  end

  # True if dispatch table has statuses queued or in progress. 
  def any_services_in_progress?
    @user_request.any_services_in_progress?
  end
  
  def app_name
    return AppConfig.param("app_name", 'Find It')
  end

  
  def display_ill?
    # Local implementor can provide custom logic in environment. See
    # same environment file.
    custom_logic = AppConfig.param('resolve_display_ill')

    return true unless custom_logic

    return custom_logic.call(@user_request)
    
    #return true if get_service_type('fulltext').empty? and get_service_type('holding').empty?
    #return false unless @user_request.referent.format == 'journal'
    #if @user_request.referent.metadata['atitle'] and @user_request.referent.metadata['atitle'] != ''
    #  return false
    #else
    #  return true
    #end
  end

  # Finds the configured index of a div with given id, in either main
  # or sidebar column. Index discovered from lists configured in
  # initializers/umlaut/resolve_views.rb
  # section should be one of "resolve_main_sections" or "resolve_sidebar_sections"
  # Returns -1 if not found. 
  # Right now only used for determining if holdings or document_delivery
  # should go first. In the future, may be used for more config
  # of resolve view. 
  def index_of_id(section, id)    
    # lazy cache
    @@resolve_view_section_indexes ||= {}
    unless (@@resolve_view_section_indexes[section])
            
      @@resolve_view_section_indexes[section] ||= {}
                  
      AppConfig.param(section).each_with_index do |defn, index|        
        id = defn[:div_id]
        @@resolve_view_section_indexes[section][ id ] = index
      end      
    end
    
    return @@resolve_view_section_indexes[section][id] || -1
  end
    
 
  
  def display_closest_web_results?  
    return '' unless (@action_name == 'index' or @action_name == 'start') and @dispatch_response.relevant_links.length > 0
    if @cookies[:umlaut_web_results] and @cookies[:umlaut_web_results] == 'false'
      return 'hideWebResults();'
    end
    if @cookies[:umlaut_web_results] and @cookies[:umlaut_web_results] == 'true'
      return 'showWebResults();'
    end
    if @context_object.referent.format == 'journal' and (@context_object.referent.metadata['atitle'].nil? or @context_object.referent.metadata['atitle'] == '')
      return 'hideWebResults();'
    end
    return 'showWebResults();'
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
  
  # Returns true if the current request is title-level only--if it has
  # no vol/iss/page number etc info.
  def title_level_request?  
    return @user_request.title_level_citation?
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
    
  
    return (metadata['genre'] != 'book' && metadata['object_id'].blank? && user_entered_citation?(@user_request) ) ? true : false
  end


  # Generate content in an expand-contract block, with a heading that
  # you can click on to show/hide it. Actual content in block.
  # Example, in view:
  #  <% expand_contract_section("My Content", "div_id_to_use") do %>
  #      this will be hidden and shown
  #  <% end %>
  def expand_contract_section(arg_heading, id, options={}, &block)
    #Defaults
    options[:initial_expand] ||= false
    # ugh, when we call this inside another partial with block, we need to pass the block.binding that we can give to concat
    options[:out_binding] ||= block.binding 
    
    # Set up proper stuff for current state.  
    expanded = (params["umlaut.show_#{id}"] == "true") || options[:initial_expand]
    opposite_value = (! expanded).to_s
    heading = ( expanded ? "Hide " : "Show ") + arg_heading
    initial_hide = ( expanded ? "" : "display: none;")
    toggle_js = " if ($('#{id}').visible())  { 
        $('#{id}').hide();
        $('#{id}_toggle_label').update('Show #{escape_javascript(arg_heading)}');
      } else {
        $('#{id}').show();
        $('#{id}_toggle_label').update('Hide #{escape_javascript(arg_heading)}');
      }"

    # Construct HTML
    html = link_to_function("<span id=\"#{id}_toggle_label\" >#{heading}</span>", 
      toggle_js,
      :href =>url_for( params.merge({'umlaut.request_id' => @user_request.id, "umlaut.show_#{id}" => opposite_value}))+"##{id}_toggle_link",
      :name => "#{id}_toggle_link",
      :class => 'expand_contract_toggle'
    )
    html += "<div id=\"#{id}\" class=\"expand_contract_content\" style=\"#{initial_hide}\">"

    # Generate
    concat(html, options[:out_binding])      
    yield()      
    concat("</div>", options[:out_binding] )            
  end
  
  def generating_embed_partials?
    return @generating_embed_partials == true
  end

  # Code-generating helper to add a "More" link to a list, with a maximum
  # number of items to show before 'more'. AJAXy show, with unobtrusive
  # degredation when no javascript. 
  # Based on the idea here for a helper that takes a block. Uses
  # expand_contract_section for actual hidden overflow. 
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
  # wrap_more_in_li: Typical idiom this is a list in <ul>, and the more
  #           link should be generated in an <li> </li>. If you want
  #           to suppress that, set false.
  # block: will be passed |item, index|, should generate html for that
  #           item in block.
  #
  # Example, in a view:
  # <% list_with_limit("div_id_for_list", list, 10) do |item, index| %>
  #     Item Number: <%= index %>: <%= item.title %>
  # <% end %>
  def list_with_limit(id, list, limit=5, &block)
    list.each_index do |index|
      item = list[index]

      yield(item, index)
      
      break if list.length > limit && index >= limit-2  
    end
    
    if (list.length > limit )

      # passing out_binding in is neccesary for this partial with block
      # inside a partial with block, bah. 
      expand_contract_section("#{list.length - limit + 1} more", id, :out_binding => block.binding) do
        (limit-1).upto(list.length-1) do |index|
          item = list[index]
          yield(item, index)
        end
      end
      
    end
  end


  def link_to_toggle_debug_info(name = "[D]", options = {})
    javascript = " $$('.debug_info').each( function(el) { el.toggle(); });"  
  
    return link_to_function(name, javascript, options)  
  end
    
  
  
end
