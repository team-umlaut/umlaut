class RemoveReferrer < ActiveRecord::Migration
  def self.up
    drop_table :referrers
  end

  def self.down
    create_table "referrers" do |t|
      t.string "identifier", :default => "", :null => false
    end
    
    add_index "referrers", ["identifier"], :name => "rfr_id_idx"
  end
end
