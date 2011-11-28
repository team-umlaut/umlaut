class ReferrerIdAsString < ActiveRecord::Migration
  def self.up
    change_column :requests, :referrer_id, :string
  end

  def self.down
    change_column :requests, :referrer_id, :integer
  end
end
