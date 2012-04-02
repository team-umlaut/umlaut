# This migration comes from umlaut (originally 1)
class UmlautInit < ActiveRecord::Migration
  def change    
    create_table "clickthroughs" do |t|
      t.integer  "request_id",          :default => 0, :null => false
      t.integer  "service_response_id", :default => 0, :null => false
      t.datetime "created_at",                         :null => false
    end
  
    add_index "clickthroughs", ["created_at"], :name => "click_created_idx"
    add_index "clickthroughs", ["request_id"], :name => "click_req_id"
    add_index "clickthroughs", ["service_response_id"], :name => "click_serv_resp_idx"
  
    create_table "dispatched_services" do |t|
      t.integer  "request_id",     :default => 0,   :null => false
      t.string   "service_id",     :default => "0", :null => false
      t.datetime "updated_at",                      :null => false
      t.text     "exception_info"
      t.string   "status",                          :null => false
      t.datetime "created_at"
    end
  
    add_index "dispatched_services", ["request_id", "service_id"], :name => "dptch_request_id"
  
    create_table "permalinks" do |t|
      t.integer "referent_id",     :default => 0
      t.date    "created_on",      :null => false
      t.text    "context_obj_serialized"
      t.string  "orig_rfr_id",     :limit => 256
      t.date    "last_access"
    end
  
    add_index "permalinks", ["referent_id"], :name => "plink_referent_idx"
  
    create_table "referent_values" do |t|
      t.integer  "referent_id",                    :default => 0,     :null => false
      t.string   "key_name",         :limit => 50, :default => "",    :null => false
      t.text     "value"
      t.string   "normalized_value"
      t.boolean  "metadata",                       :default => false, :null => false
      t.boolean  "private_data",                   :default => false, :null => false
      t.datetime "created_at"
    end
  
    add_index "referent_values", ["key_name", "normalized_value"], :name => "by_name_and_normal_val"
    add_index "referent_values", ["referent_id", "key_name", "normalized_value"], :name => "rft_val_referent_idx"
  
    create_table "referents" do |t|
      t.string   "atitle"
      t.string   "title"
      t.string   "issn",       :limit => 10
      t.string   "isbn",       :limit => 13
      t.string   "year",       :limit => 4
      t.string   "volume",     :limit => 10
      t.datetime "created_at"
    end
  
    add_index "referents", ["atitle", "title", "issn", "isbn", "year", "volume"], :name => "rft_shortcut_idx"
    add_index "referents", ["isbn"], :name => "index_referents_on_isbn"
    add_index "referents", ["issn", "year", "volume"], :name => "by_issn"
    add_index "referents", ["title"], :name => "index_referents_on_title"
    add_index "referents", ["volume"], :name => "index_referents_on_volume"
    add_index "referents", ["year", "volume"], :name => "by_year"
  
    create_table "requests" do |t|
      t.string   "session_id",             :limit => 100,  :default => "", :null => false
      t.integer  "referent_id",                            :default => 0,  :null => false
      t.string   "referrer_id"
      t.datetime "created_at",                                             :null => false
      t.string   "client_ip_addr"
      t.boolean  "client_ip_is_simulated"
      t.string   "contextobj_fingerprint", :limit => 32
      t.string   "http_env",               :limit => 2048
    end
  
    add_index "requests", ["client_ip_addr"], :name => "index_requests_on_client_ip_addr"
    add_index "requests", ["contextobj_fingerprint"], :name => "index_requests_on_contextobj_fingerprint"
    add_index "requests", ["created_at"], :name => "req_created_at"
    add_index "requests", ["referent_id", "referrer_id"], :name => "context_object_idx"
    add_index "requests", ["session_id"], :name => "req_sess_idx"
  
    create_table "service_responses" do |t|
      t.string   "service_id",              :limit => 25,                   :null => false
      t.string   "response_key",                            :default => ""
      t.string   "value_string"
      t.string   "value_alt_string"
      t.text     "value_text"
      t.string   "display_text"
      t.string   "url",                     :limit => 1024
      t.text     "notes"
      t.text     "service_data"
      t.datetime "created_at"
      t.string   "service_type_value_name"
      t.integer  "request_id"
    end
  
    add_index "service_responses", ["service_id", "response_key", "value_string", "value_alt_string"], :name => "svc_resp_service_id"
    
    create_table "sfx_urls" do |t|
      t.string "url"
    end
  
    add_index "sfx_urls", ["url"], :name => "index_sfx_urls_on_url"

  end
end
