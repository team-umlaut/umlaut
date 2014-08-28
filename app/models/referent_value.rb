class ReferentValue < ActiveRecord::Base
  belongs_to :referent, lambda { includes :referent_values }

  # Class method to normalize a string for normalized_value attribute. 
  # Right now normalization is just downcasing. Only
  # metadata values should be normalized (ie, not 'identifier' or 'format').
  # identifier and format shoudl be stored in normalized_value unchanged.
  def self.normalize(input)
      return input.scrub.downcase.to_s[0..254]
  end
  
end
