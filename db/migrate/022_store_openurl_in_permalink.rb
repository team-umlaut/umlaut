class StoreOpenurlInPermalink < ActiveRecord::Migration
  def self.up
    add_column :permalinks, :context_obj_serialized, :text
    change_column :permalinks, :referent_id, :integer, :null => true
  end

  def self.down
    remove_column :permalinks, :context_obj_serialized
    change_column :permalinks, :referent_id, :integer, :default => 0, :null => false
  end
end
