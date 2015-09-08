# An ActiveRecord extension that will let you automatically truncate
# certain attributes to the maximum length allowed by the DB. 
#
#     require 'truncate_to_db_limit'
#     class Something < ActiveRecord::Base
#        include TruncateToDbLimit
#        truncate_to_db_limit :short_attr, :short_attr2
#        #...
#
# Truncation is done in a before_validate hook, so won't happen until
# you try to save. 
#
module TruncateToDbLimit
  extend ActiveSupport::Concern

  included do 
    class_attribute :'_truncate_to_db_limit_attributes', instance_accessor: false
    before_validation :do_truncate_to_db_limit!


    def self.truncate_to_db_limit(*attribute_names)   
      self._truncate_to_db_limit_attributes = attribute_names
    end
  end




  def do_truncate_to_db_limit!
    
    
    self.class._truncate_to_db_limit_attributes.each do |attribute_name|

      ar_attr = self.class.columns_hash[attribute_name.to_s]

      unless ar_attr
        raise ArgumentError.new("truncate_to_db_limit #{attribute_name}: No such attribute")
      end

      limit   = ar_attr.limit

      unless limit && limit.to_i != 0
        return # we can do nothing
        #raise ArgumentError.new("truncate_to_db_limit #{attribute_name}: Limit not known")
      end

      normalized = send(attribute_name).try {|v| v.slice(0, limit)}
      send("#{attribute_name}=", normalized)
    end
  end

end