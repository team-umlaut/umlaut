class CreateServiceTypes < ActiveRecord::Migration
  def self.up
    create_table :service_types do |t|
    end
  end

  def self.down
    drop_table :service_types
  end
end
