class CreatePrintLocations < ActiveRecord::Migration
  def self.up
    create_table :print_locations do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :print_locations
  end
end
