class CreateDocdelServices < ActiveRecord::Migration
  def self.up
    create_table :docdel_services do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :docdel_services
  end
end
