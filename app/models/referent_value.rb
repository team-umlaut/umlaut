class ReferentValue < ActiveRecord::Base
  belongs_to :referent


  def self.normalize(input)
      return input.chars.downcase.to_s
  end
end
