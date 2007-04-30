class Journal < ActiveRecord::Base
  require 'acts_as_ferret'
  has_many :journal_titles
  has_many :coverages
  has_and_belongs_to_many :categories
  belongs_to :title_source
  acts_as_ferret :fields => [:title, :alternate_titles, :subjects]
  def self.find_similar(journal)
    categories = []
    journal_cats = []
    journal.categories.each { | cat |
      j_ids = []
      cat.journals.each { | j |
        j_ids << j.id
      }
      journal_cats << j_ids
    }
    if journal_cats.length == 0
      return false
    elsif journal_cats.length == 1
      return journal.categories[0].journals
    else
      sim_ids = []
      journal_cats.each { | journcat |
        if sim_ids.length == 0
          sim_ids = journcat
          next
        else
          sim_ids = journcat&sim_ids
        end
   
      }
      return Journal.find(:all, :conditions=>'id in ('+sim_ids.join(",")+')')
    end
    
  end
  
  def alternate_titles
    titles = []
    self.journal_titles.each do | jrnl_title |
      titles << jrnl_title.title
    end
    return titles.join(" ")
  end
  
  def subjects
    subjects = []
    self.categories.each do | category |
      subjects << category.category+' '+category.subcategory
    end
    return subjects.join(" ")
  end  
end
