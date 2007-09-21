class CreateSfxUrls < ActiveRecord::Migration
  def self.up
    create_table :sfx_urls do |t|
      t.column :url, :string
    end
    add_index :sfx_urls, :url
  end

  def self.down
    drop_table :sfx_urls
  end
end
