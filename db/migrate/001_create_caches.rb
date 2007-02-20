class CreateCaches < ActiveRecord::Migration
  def self.up
    create_table :caches do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :caches
  end
end
