class CreateOaiTargets < ActiveRecord::Migration
  def self.up
    create_table :oai_targets do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :oai_targets
  end
end
