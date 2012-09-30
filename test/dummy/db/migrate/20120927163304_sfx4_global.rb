# Create a test SFX Global DB.
class Sfx4Global < ActiveRecord::Migration
  def connection
    ActiveRecord::Base.establish_connection(:sfx4_global)
    ActiveRecord::Base.connection.initialize_schema_migrations_table
    ActiveRecord::Base.connection
  end

  def change    
    create_table "KB_OBJECTS", {:id => false} do |t|
      t.integer  "OBJECT_ID", :default => 0, :null => false, :limit => 8
    end
    execute "ALTER TABLE KB_OBJECTS ADD PRIMARY KEY (OBJECT_ID);"
  end
end
