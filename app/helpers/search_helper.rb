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
        result.atitle = t(:chapter_title)
      when @current_context_object.referent.format == 'journal'
        result.atitle = t(:article_title)
      end
      result.title = t(:title)
    else
      case ref_meta["genre"]
      when /article|journal|issue/
        result.atitle = t(:article_title)
        result.title = t(:journal_title)
      when /bookitem|book/
        result.atitle = t(:chapter_title)
        result.title = t(:book_title)
      when /proceeding|conference/
        result.atitle = t(:proceeding_title)
        result.title = t(:conference_name)
      when 'report'
        result.atitle = t(:report_title)
        result.title = t(:report)
      end
    end
    return result    
  end
  
  # A-Z buttons in search page
  def group_list
    group_list ||= ('A'..'Z').to_a.push('0-9').push(t(:other))
  end

  # Date dropdowns in search page
  def date
    years + months + days
  end

  def years
    select_year(nil, {:prompt => true, :start_year => Date.today.year, :end_year => 1950}, {:name => "__year", :class=>"year input-small"})
  end

  def months
    select_month(nil, {:prompt => true, :use_short_month => true}, {:name => "__month", :class=>"month input-small"})
  end

  def days
    select_day(nil, {:prompt => true}, {:name => "__day", :class=>"day input-small"})
  end
end