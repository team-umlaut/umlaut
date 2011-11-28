class RemoveTitleSource < ActiveRecord::Migration
  def self.up
    drop_table :title_sources
  end

  def self.down
    create_table "title_sources", :force => true do |t|
      t.string "name",     :limit => 50, :default => "", :null => false
      t.text   "location",                               :null => false
      t.text   "filename",                               :null => false
    end
  end
end
