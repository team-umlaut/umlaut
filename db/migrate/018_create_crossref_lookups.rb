class CreateCrossrefLookups < ActiveRecord::Migration
  def self.up
    create_table :crossref_lookups do |t|
      t.column "doi", :string, :limit => "100", :default => "", :null => false
      t.column "created_on", :datetime
    end
    add_index :crossref_lookups, ["doi", "created_on"], :name => 'xref_lookup_doi'
  end

  def self.down
    drop_table :crossref_lookups
  end
end
