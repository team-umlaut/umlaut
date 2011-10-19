class DropRelevantSitesTables < ActiveRecord::Migration
  def self.up
    drop_table :irrelevant_sites
    drop_table :relevant_sites
  end

  def self.down
    create_table "irrelevant_sites", :force => true do |t|
      t.string "hostname", :default => "", :null => false
    end
    add_index "irrelevant_sites", ["hostname"], :name => "irrev_hostname"
    
    
    create_table "relevant_sites", :force => true do |t|
      t.string "hostname",               :default => "", :null => false
      t.string "type",     :limit => 25
    end
    add_index "relevant_sites", ["hostname"], :name => "rel_hostname"


  end
end
