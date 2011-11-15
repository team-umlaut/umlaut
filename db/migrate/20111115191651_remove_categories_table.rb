class RemoveCategoriesTable < ActiveRecord::Migration
  def self.up
    drop_table :categories
    drop_table :categories_journals
  end

  def self.down
    create_table "categories" do |t|
      t.string "category",    :limit => 100, :default => "", :null => false
      t.string "subcategory", :limit => 100
    end
  
    add_index "categories", ["subcategory"], :name => "subcat_idx"
  
    create_table "categories_journals", :id => false do |t|
      t.integer "journal_id",  :default => 0, :null => false
      t.integer "category_id", :default => 0, :null => false
    end
  
    add_index "categories_journals", ["journal_id", "category_id"], :name => "journ_cat_idx"
      
  end
end
