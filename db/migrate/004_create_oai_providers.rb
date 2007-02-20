class CreateOaiProviders < ActiveRecord::Migration
  def self.up
    create_table :oai_providers do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :oai_providers
  end
end
