class RemoveCrossrefCache < ActiveRecord::Migration
  def self.up
    drop_table :crossref_lookups
  end

  def self.down
    create_table "crossref_lookups" do |t|
      t.string   "doi",        :limit => 100, :default => "", :null => false
      t.datetime "created_on"
    end
    
    add_index "crossref_lookups", ["doi", "created_on"], :name => "xref_lookup_doi"
  end
end
