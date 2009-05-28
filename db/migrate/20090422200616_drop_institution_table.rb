class DropInstitutionTable < ActiveRecord::Migration
  def self.up
    drop_table :institutions
  end

  def self.down
    create_table "institutions" do |t|
      t.column "name", :string, :default => "", :null => false
      t.column "default_institution", :boolean, :default => false, :null => false
      t.column "worldcat_registry_id", :string, :limit => 25
      t.column "configuration", :text
      t.column "updated_at", :date
	  end
  end
end
