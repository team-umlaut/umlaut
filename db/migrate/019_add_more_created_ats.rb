class AddMoreCreatedAts < ActiveRecord::Migration
  def self.up
    add_column :referent_values, :created_at, :datetime
    add_column :referents, :created_at, :datetime
  end

  def self.down
    remove_column :referent_values, :created_at
    remove_column :referents, :created_at
  end
end
