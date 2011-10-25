module ExportEmailHelper
  include EmailerHelper
  
  def formatted_txt_holding_status(view_data)
    output = ""

    output << view_data[:collection_str] if view_data[:collection_str]
    output << " " + view_data[:call_number] if view_data[:call_number]
    output << " " + view_data[:status] if view_data[:status]
    
    return output
  end

  def formatted_html_holding_status(view_data)
    output = "".html_safe

    
    if view_data[:collection_str]
      output << content_tag("span", view_data[:collection_str], :class => "collection") 
    end
    if view_data[:call_number]
      output << " ".html_safe << content_tag("span", view_data[:call_number], :class => "call_no")
    end
    if view_data[:status]
      output << " ".html_safe << content_tag("span", view_data[:status], :class => "status")
    end
      
    return output
  end


  # We override form_remote_tag to add a paramter :remote which if
  # set to false will generate an ordinary form instead of a remote form.
  def form_remote_tag(options = {}, &block)        
    if ( options[:remote] != false)
      super(options, &block)
    else
      new_options = options[:html]
      url = new_options.delete(:action)
      form_tag(url, new_options, &block)
    end
  end

  
end
