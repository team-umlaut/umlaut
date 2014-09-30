# An ActiveRecord extension that will let you automatically truncate
# certain attributes to the maximum length allowed by the DB. 
#
#     require 'truncate_to_db_limit'
#     class Something < ActiveRecord::Base
#        extend TruncateToDbLimit
#        truncate_to_db_limit :short_attr, :short_attr2
#        #...
#
# Truncation is done whenever the attribute is set, NOT waiting
# until db save. 
#
# For a varchar(4), if you do:
#    model.short_attr = "123456789"
#    model.short_attr # => '1234'
#
#
# We define an override to the `attribute_name=` method, which ActiveRecord, I think,
# promises to call just about all the time when setting the attribute. We call super
# after truncating the value. 
module TruncateToDbLimit

  def truncate_to_db_limit(*attribute_names)
    attribute_names.each do |attribute_name|
      ar_attr = columns_hash[attribute_name.to_s]

      unless ar_attr
        raise ArgumentError.new("truncate_to_db_limit #{attribute_name}: No such attribute")
      end

      limit   = ar_attr.limit

      unless limit && limit.to_i != 0
        raise ArgumentError.new("truncate_to_db_limit #{attribute_name}: Limit not known")
      end

      define_method "#{attribute_name}=" do |val|
        normalized = val.slice(0, limit)
        super(normalized)
      end

    end
  end
end