# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090526192301) do

  create_table "categories", :force => true do |t|
    t.string "category",    :limit => 100, :default => "", :null => false
    t.string "subcategory", :limit => 100
  end

  add_index "categories", ["subcategory"], :name => "subcat_idx"

  create_table "categories_journals", :id => false, :force => true do |t|
    t.integer "journal_id",  :default => 0, :null => false
    t.integer "category_id", :default => 0, :null => false
  end

  add_index "categories_journals", ["journal_id", "category_id"], :name => "journ_cat_idx"

  create_table "clickthroughs", :force => true do |t|
    t.integer  "request_id",          :default => 0, :null => false
    t.integer  "service_response_id", :default => 0, :null => false
    t.datetime "created_at",                         :null => false
  end

  add_index "clickthroughs", ["request_id"], :name => "click_req_id"
  add_index "clickthroughs", ["service_response_id"], :name => "click_serv_resp_idx"
  add_index "clickthroughs", ["created_at"], :name => "click_created_idx"

  create_table "coverages", :force => true do |t|
    t.integer "journal_id", :default => 0,  :null => false
    t.string  "provider",   :default => "", :null => false
    t.text    "coverage"
  end

  add_index "coverages", ["journal_id"], :name => "cvg_jrnl_id_idx"

  create_table "crossref_lookups", :force => true do |t|
    t.string   "doi",        :limit => 100, :default => "", :null => false
    t.datetime "created_on"
  end

  add_index "crossref_lookups", ["doi", "created_on"], :name => "xref_lookup_doi"

  create_table "dispatched_services", :force => true do |t|
    t.integer  "request_id",     :default => 0,   :null => false
    t.string   "service_id",     :default => "0", :null => false
    t.datetime "updated_at",                      :null => false
    t.text     "exception_info"
    t.string   "status",         :default => "",  :null => false
    t.datetime "created_at"
  end

  add_index "dispatched_services", ["request_id", "service_id"], :name => "dptch_request_id"

  create_table "institutions_users", :force => true do |t|
    t.integer "institution_id", :default => 0, :null => false
    t.integer "user_id",        :default => 0, :null => false
    t.integer "priority",       :default => 0, :null => false
  end

  add_index "institutions_users", ["institution_id", "user_id", "priority"], :name => "instuserpri_id"

  create_table "irrelevant_sites", :force => true do |t|
    t.string "hostname", :default => "", :null => false
  end

  add_index "irrelevant_sites", ["hostname"], :name => "irrev_hostname"

  create_table "journal_titles", :force => true do |t|
    t.string  "title",      :default => "", :null => false
    t.integer "journal_id", :default => 0,  :null => false
  end

  add_index "journal_titles", ["title", "journal_id"], :name => "jtitle_title_objects"

  create_table "journals", :force => true do |t|
    t.string   "object_id",        :limit => 20, :default => "", :null => false
    t.string   "title",                          :default => "", :null => false
    t.string   "normalized_title",               :default => "", :null => false
    t.string   "page",             :limit => 1,  :default => "", :null => false
    t.string   "issn",             :limit => 10
    t.string   "eissn",            :limit => 10
    t.integer  "title_source_id",                :default => 0,  :null => false
    t.datetime "updated_at"
  end

  add_index "journals", ["object_id"], :name => "j_object_id"
  add_index "journals", ["normalized_title", "page"], :name => "jrnl_norm_title"
  add_index "journals", ["title_source_id"], :name => "jrnl_title_source_id"
  add_index "journals", ["title"], :name => "jrnl_title_idx"
  add_index "journals", ["issn", "eissn"], :name => "jrnl_issn_idx"
  add_index "journals", ["updated_at"], :name => "jrnl_tstamp_idx"

  create_table "keywords", :force => true do |t|
    t.string "term",         :default => "", :null => false
    t.string "keyword_type", :default => "", :null => false
  end

  add_index "keywords", ["term", "keyword_type"], :name => "kwd_term_idx"

  create_table "permalinks", :force => true do |t|
    t.integer "referent_id",                           :default => 0
    t.date    "created_on",                                           :null => false
    t.text    "context_obj_serialized"
    t.string  "orig_rfr_id",            :limit => 256
  end

  add_index "permalinks", ["referent_id"], :name => "plink_referent_idx"

  create_table "referent_values", :force => true do |t|
    t.integer  "referent_id",                    :default => 0,     :null => false
    t.string   "key_name",         :limit => 50, :default => "",    :null => false
    t.text     "value"
    t.string   "normalized_value"
    t.boolean  "metadata",                       :default => false, :null => false
    t.boolean  "private_data",                   :default => false, :null => false
    t.datetime "created_at"
  end

  add_index "referent_values", ["referent_id", "key_name", "normalized_value"], :name => "rft_val_referent_idx"
  add_index "referent_values", ["key_name", "normalized_value"], :name => "by_name_and_normal_val"

  create_table "referents", :force => true do |t|
    t.string   "atitle"
    t.string   "title"
    t.string   "issn",       :limit => 10
    t.string   "isbn",       :limit => 13
    t.string   "year",       :limit => 4
    t.string   "volume",     :limit => 10
    t.datetime "created_at"
  end

  add_index "referents", ["atitle", "title", "issn", "isbn", "year", "volume"], :name => "rft_shortcut_idx"
  add_index "referents", ["title"], :name => "index_referents_on_title"
  add_index "referents", ["issn", "year", "volume"], :name => "by_issn"
  add_index "referents", ["isbn"], :name => "index_referents_on_isbn"
  add_index "referents", ["year", "volume"], :name => "by_year"
  add_index "referents", ["volume"], :name => "index_referents_on_volume"

  create_table "referrers", :force => true do |t|
    t.string "identifier", :default => "", :null => false
  end

  add_index "referrers", ["identifier"], :name => "rfr_id_idx"

  create_table "relevant_sites", :force => true do |t|
    t.string "hostname",               :default => "", :null => false
    t.string "type",     :limit => 25
  end

  add_index "relevant_sites", ["hostname"], :name => "rel_hostname"

  create_table "requests", :force => true do |t|
    t.string   "session_id",             :limit => 100,  :default => "", :null => false
    t.integer  "referent_id",                            :default => 0,  :null => false
    t.integer  "referrer_id"
    t.datetime "created_at",                                             :null => false
    t.string   "client_ip_addr"
    t.boolean  "client_ip_is_simulated"
    t.string   "contextobj_fingerprint", :limit => 32
    t.string   "http_env",               :limit => 2048
  end

  add_index "requests", ["referent_id", "referrer_id"], :name => "context_object_idx"
  add_index "requests", ["session_id"], :name => "req_sess_idx"
  add_index "requests", ["created_at"], :name => "req_created_at"
  add_index "requests", ["client_ip_addr"], :name => "index_requests_on_client_ip_addr"
  add_index "requests", ["contextobj_fingerprint"], :name => "index_requests_on_contextobj_fingerprint"

  create_table "service_responses", :force => true do |t|
    t.string   "service_id",       :limit => 25,   :default => "", :null => false
    t.string   "response_key",                     :default => ""
    t.string   "value_string"
    t.string   "value_alt_string"
    t.text     "value_text"
    t.string   "display_text"
    t.string   "url",              :limit => 1024
    t.text     "notes"
    t.text     "service_data"
    t.datetime "created_at"
  end

  add_index "service_responses", ["service_id", "response_key", "value_string", "value_alt_string"], :name => "svc_resp_service_id"

  create_table "service_type_values", :force => true do |t|
    t.string   "name"
    t.string   "display_name"
    t.string   "display_name_plural"
    t.datetime "updated_at"
    t.string   "section_heading"
    t.string   "section_prompt"
  end

  create_table "service_types", :force => true do |t|
    t.integer "request_id",            :default => 0, :null => false
    t.integer "service_response_id",   :default => 0, :null => false
    t.integer "service_type_value_id",                :null => false
  end

  add_index "service_types", ["request_id", "service_response_id"], :name => "svc_type_idx"
  add_index "service_types", ["service_type_value_id"], :name => "index_service_types_on_service_type_value_id"
  add_index "service_types", ["service_response_id"], :name => "index_service_types_on_service_response_id"

  create_table "sessions", :force => true do |t|
    t.string   "session_id"
    t.text     "data"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "sfx_urls", :force => true do |t|
    t.string "url"
  end

  add_index "sfx_urls", ["url"], :name => "index_sfx_urls_on_url"

  create_table "title_sources", :force => true do |t|
    t.string "name",     :limit => 50, :default => "", :null => false
    t.text   "location",                               :null => false
    t.text   "filename",                               :null => false
  end

  create_table "users", :force => true do |t|
    t.string "username",  :limit => 50,  :default => "", :null => false
    t.string "firstname", :limit => 100
    t.string "lastname",  :limit => 100
    t.string "email"
  end

  add_index "users", ["username"], :name => "user_username_idx"

end
