class AddRfrIdToPermalink < ActiveRecord::Migration
  def self.up
    add_column :permalinks, :orig_rfr_id, :string, :limit => 256
  end

  def self.down
    remove_column :permalinks, :orig_rfr_id
  end

 
end
