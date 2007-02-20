class CreateSimilarItems < ActiveRecord::Migration
  def self.up
    create_table :similar_items do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :similar_items
  end
end
