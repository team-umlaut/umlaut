class CreateDescriptions < ActiveRecord::Migration
  def self.up
    create_table :descriptions do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :descriptions
  end
end
