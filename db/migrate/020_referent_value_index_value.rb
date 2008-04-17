class ReferentValueIndexValue < ActiveRecord::Migration
  def self.up
    remove_index :referent_values, :key_name
    add_index :referent_values, [:key_name, :normalized_value], :name => 'by_name_and_normal_val'

    # To re-use a request, we often look up by session id and serialized params
    # string, so including that in the index works best. Nevermind, not needed.
    #remove_index :requests, [:session_id], :name => 'req_sess_idx'
    #add_index :requests, [:session_id, :params], :name => 'by_session_id_and_params'
  end

  def self.down
    remove_index :referent_values, :name => 'by_name_and_normal_val'
    add_index :referent_values, :key_name

    #remove_index :requests, :name => 'by_session_id_and_params'
    #add_index :requests, [:session_id], :name => 'req_sess_idx'
  end
end
