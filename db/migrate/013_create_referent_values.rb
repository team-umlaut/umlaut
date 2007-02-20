class CreateReferentValues < ActiveRecord::Migration
  def self.up
    create_table :referent_values do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :referent_values
  end
end
