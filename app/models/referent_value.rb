class ReferentValue < ActiveRecord::Base
  if Rails::VERSION::MAJOR >= 4
    belongs_to :referent, lambda { includes :referent_values }
  else
    belongs_to :referent, :include => :referent_values
  end

  # Class method to normalize a string for normalized_value attribute. 
  # Right now normalization is just downcasing. Only
  # metadata values should be normalized (ie, not 'identifier' or 'format').
  # identifier and format shoudl be stored in normalized_value unchanged.
  def self.normalize(input)
      return input.scrub.downcase.to_s[0..254]
  end
  
end
