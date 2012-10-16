# This is used for SFX search testing.
# DO NOT USE THIS FOR ANYTHING LIKE A REAL SFX DATABASE.
class Sfx4Global < ActiveRecord::Migration
  def connection
    if sfx4_mock_instance?
      Sfx4::Global::Base.connection.initialize_schema_migrations_table
      connection = Sfx4::Global::Base.connection
      puts Sfx4::Global::Base.connection.inspect
      return connection
    end
  end

  def change
    if sfx4_mock_instance?
      create_table "KB_OBJECTS", {:id => false} do |t|
        t.integer "OBJECT_ID", :default => 0, :null => false, :limit => 8
      end
      execute "ALTER TABLE KB_OBJECTS ADD PRIMARY KEY (OBJECT_ID);"
    else
      puts "Skipping SFX Global migration since SFX global DB specified is not a mock instance."
    end
  end

  def sfx4_mock_instance?
    (ActiveRecord::Base.configurations["sfx4_global"] and
      ActiveRecord::Base.configurations["sfx4_global"]["mock_instance"])
  end
end