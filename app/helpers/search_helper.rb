require 'ostruct'

module SearchHelper

  def search_result_target_window
    umlaut_config.lookup!("search.result_link_target","")
  end

  # pass in an openurl context obj.
  # return an OpenStruct with atitle_label, title_label
  def referent_labels(context_obj = @current_context_object)
    ref_meta = context_obj.referent.metadata
    
    result = OpenStruct.new
    
    if ref_meta['genre'].blank?
      case @current_context_object.referent.format 
      when  'book'
        result.atitle = 'Chapter/Part Title'
      when @current_context_object.referent.format == 'journal'
        result.atitle = 'Article Title'
      end
      result.title = 'Title'      
    else
      case ref_meta["genre"]
      when /article|journal|issue/
        result.atitle = 'Article Title'
        result.title = 'Journal Title'
      when /bookitem|book/
        result.atitle = 'Chapter/Part Title'
        result.title = 'Book Title'
      when /proceeding|conference/
        result.atitle = 'Proceeding Title'
        result.title = 'Conference Name'
      when 'report'
        result.atitle = 'Report Title'
        result.title = 'Report'
      end
    end

    return result    
  end
  
  # A-Z buttons in search page
  def group_list
    group_list ||= ('A'..'Z').to_a.push('0-9').push('Other')  
  end
  

end
