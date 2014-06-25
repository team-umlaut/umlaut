require 'ostruct'

module SearchHelper

  def search_result_target_window
    umlaut_config.lookup!("search.result_link_target","")
  end

  # pass in an openurl context obj.
  # return an OpenStruct with :atitle and :title labels
  #
  # Uses i18n
  #
  # Much of this duplicates Referent.type_thing_name and container_type_of_thing, 
  # although we don't have a Referent here, that logic should be combined. TODO
  def referent_labels(context_obj = @current_context_object)
    ref_meta = context_obj.referent.metadata
    result = OpenStruct.new

    type_of_thing_key = ref_meta['genre']
    type_of_thing_key = context_obj.referent.format if type_of_thing_key.blank?
    type_of_thing_key = type_of_thing_key.downcase

    a_key = type_of_thing_key
    if a_key == "journal" && ref_meta['atitle'].present?
      a_key = "article"
    end
    result.atitle = I18n.t(a_key, :scope => "umlaut.citation.genre", :default => "")

    c_key = type_of_thing_key
    c_key = 'journal' if c_key == "article"
    c_key = 'book'    if c_key == "bookitem"
    result.title =  I18n.t(i18n_key, :scope => "umlaut.citation.genre", :default => "")

    return result    
  end
  
  # A-Z buttons in search page
  def group_list
    group_list ||= ('A'..'Z').to_a.push('0-9').push(t('umlaut.search.browse_other'))
  end

  # Date dropdowns in search page
  def search_date_select
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