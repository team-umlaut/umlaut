class JournalTitle < ActiveRecord::Base
  belongs_to :journal, :foreign_key=>'object_id'

  # To let code set as read-only, used to create fake objects
  # that were fetched from SFX etc. AR will do the right thing
  # if we set @readonly properly. 
  attr_writer :readonly
  
end
