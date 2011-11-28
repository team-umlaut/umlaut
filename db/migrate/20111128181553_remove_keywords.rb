class RemoveKeywords < ActiveRecord::Migration
  def self.up
    drop_table :keywords
  end

  def self.down
    create_table "keywords" do |t|
      t.string "term",         :default => "", :null => false
      t.string "keyword_type", :default => "", :null => false
    end
    
    add_index "keywords", ["term", "keyword_type"], :name => "kwd_term_idx"
  end
end
