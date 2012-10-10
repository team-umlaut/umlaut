# This is used for SFX search testing.
# DO NOT USE THIS FOR ANYTHING LIKE A REAL SFX DATABASE.
class Sfx4Global < ActiveRecord::Migration
  def connection
    ActiveRecord::Base.establish_connection(:sfx4_global)
    ActiveRecord::Base.connection.initialize_schema_migrations_table
    ActiveRecord::Base.connection
  end

  def change
    unless_testing_raise_error
    create_table "KB_OBJECTS", {:id => false} do |t|
      t.integer "OBJECT_ID", :default => 0, :null => false, :limit => 8
    end
    execute "ALTER TABLE KB_OBJECTS ADD PRIMARY KEY (OBJECT_ID);"
  end

  def unless_testing_raise_error
    unless ActiveRecord::Base.configurations["sfx4_global"]["mock_instance"]
      raise SecurityError.new("Danger! This is for mock SFX testing only! Do not run this migration against any sort of real SFX database.")
    end
  end
end
