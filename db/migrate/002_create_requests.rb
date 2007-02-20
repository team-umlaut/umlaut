class CreateRequests < ActiveRecord::Migration
  def self.up
    create_table :requests do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :requests
  end
end
