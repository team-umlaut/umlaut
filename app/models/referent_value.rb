class ReferentValue < ActiveRecord::Base
  attr_accessible :key_name, :value, :normalized_value, :metadata, :private_data
  belongs_to :referent, :include => :referent_values

  # Class method to normalize a string for normalized_value attribute. 
  # Right now normalization is just downcasing. Only
  # metadata values should be normalized (ie, not 'identifier' or 'format').
  # identifier and format shoudl be stored in normalized_value unchanged.
  def self.normalize(input)
      # 'mb_chars' is neccesary for unicode.
      # normalized_value column only holds 254 bytes.. 
      return input.mb_chars.downcase.to_s[0..254]
  end
  
end
