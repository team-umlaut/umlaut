class AddSessions < ActiveRecord::Migration
  def self.up
    # Drop pre-existing weird one for Rails standard one.
    drop_table :sessions
    
    create_table :sessions do |t|
      t.column :session_id, :string
      t.column :data, :text
      t.column :updated_at, :datetime
    end

    add_index :sessions, :session_id
    add_index :sessions, :updated_at
  end

  def self.down
    drop_table :sessions

    # Add original weird one. 
    create_table "sessions", :force => true do |t|
	    t.column "sessid", :string, :limit => 32
      t.column "data", :text
	  end
  end
end
