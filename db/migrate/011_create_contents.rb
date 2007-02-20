class CreateContents < ActiveRecord::Migration
  def self.up
    create_table :contents do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :contents
  end
end
