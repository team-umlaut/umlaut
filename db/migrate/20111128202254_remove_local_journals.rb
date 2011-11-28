class RemoveLocalJournals < ActiveRecord::Migration
  def self.up
    drop_table :coverages
    drop_table :journal_titles
    drop_table :journals
  end

  def self.down
    create_table "journals" do |t|
      t.string   "object_id",        :limit => 20, :default => "", :null => false
      t.string   "title",                          :default => "", :null => false
      t.string   "normalized_title",               :default => "", :null => false
      t.string   "page",             :limit => 1,  :default => "", :null => false
      t.string   "issn",             :limit => 10
      t.string   "eissn",            :limit => 10
      t.integer  "title_source_id",                :default => 0,  :null => false
      t.datetime "updated_at"
    end
    
    add_index "journals", ["issn", "eissn"], :name => "jrnl_issn_idx"
    add_index "journals", ["normalized_title", "page"], :name => "jrnl_norm_title"
    add_index "journals", ["object_id"], :name => "j_object_id"
    add_index "journals", ["title"], :name => "jrnl_title_idx"
    add_index "journals", ["title_source_id"], :name => "jrnl_title_source_id"
    add_index "journals", ["updated_at"], :name => "jrnl_tstamp_idx"
    
    create_table "journal_titles" do |t|
      t.string  "title",      :default => "", :null => false
      t.integer "journal_id", :default => 0,  :null => false
    end
    add_index "journal_titles", ["title", "journal_id"], :name => "jtitle_title_objects"
    
    create_table "coverages" do |t|
      t.integer "journal_id", :default => 0,  :null => false
      t.string  "provider",   :default => "", :null => false
      t.text    "coverage"
    end
    add_index "coverages", ["journal_id"], :name => "cvg_jrnl_id_idx"
  end
end
