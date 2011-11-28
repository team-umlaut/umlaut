class RemoveUsers < ActiveRecord::Migration
  def self.up
    drop_table :users
  end

  def self.down    
    create_table "users", :force => true do |t|
      t.string "username",  :limit => 50,  :default => "", :null => false
      t.string "firstname", :limit => 100
      t.string "lastname",  :limit => 100
      t.string "email"
    end
    
    add_index "users", ["username"], :name => "user_username_idx"

  end
end
