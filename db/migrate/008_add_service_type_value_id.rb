class AddServiceTypeValueId < ActiveRecord::Migration
  def self.up
    add_column :service_types, :service_type_value_id, :integer, :null => false

    # Okay, we're going to do the really time consuming data migration.
    # If it has 'fulltext' in service_type, it should have
    # ServiceTypeValue[:fulltext].id in service_type_value_id
    puts "Migrating data. This will be time consuming if you have a lot of ServiceType rows."
    objs = ServiceType.find(:all)
    objs.each do |st|
      st.update_attribute( :service_type_value_id, ServiceTypeValue[st.service_type])
    end
  end

  def self.down
    remove_column :service_types, :service_type_value_id
  end
end
