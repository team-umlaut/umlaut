class AddRequestContextobjFingerprint < ActiveRecord::Migration
  def self.up
    add_column :requests, :contextobj_fingerprint, :string, :limit => 32
    add_index :requests, :contextobj_fingerprint
  end

  def self.down
    remove_index :requests, :contextobj_fingerprint
    remove_column :requests, :contextobj_fingerprint    
  end
end
