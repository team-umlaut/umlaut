require 'acts_as_ferret'
class JournalTitle < ActiveRecord::Base
  belongs_to :journal, :foreign_key=>'object_id'
  acts_as_ferret
end
