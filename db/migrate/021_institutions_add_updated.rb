class InstitutionsAddUpdated < ActiveRecord::Migration
  def self.up
    add_column :institutions, :updated_at, :datetime
  end

  def self.down
    remove_column :institutions, :updated_at
  end
end
