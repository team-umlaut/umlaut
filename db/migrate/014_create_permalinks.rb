class CreatePermalinks < ActiveRecord::Migration
  def self.up
    create_table :permalinks do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :permalinks
  end
end
