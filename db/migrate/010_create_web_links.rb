class CreateWebLinks < ActiveRecord::Migration
  def self.up
    create_table :web_links do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :web_links
  end
end
