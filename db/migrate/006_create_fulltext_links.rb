class CreateFulltextLinks < ActiveRecord::Migration
  def self.up
    create_table :fulltext_links do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :fulltext_links
  end
end
