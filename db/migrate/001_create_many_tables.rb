# Create a whole bunch of tables in one migration. 

class CreateManyTables < ActiveRecord::Migration
  def self.up
	  create_table "categories", :force => true do |t|
	  t.column "category", :string, :limit => 100, :default => "", :null => false
	  t.column "subcategory", :string, :limit => 100
	  end
	  
	  add_index "categories", ["subcategory"], :name => "subcat_idx"
	  
	  create_table "categories_journals", :id => false, :force => true do |t|
	  t.column "journal_id", :integer, :default => 0, :null => false
	  t.column "category_id", :integer, :default => 0, :null => false
	  end
	  
	  add_index "categories_journals", ["journal_id", "category_id"], :name => "journ_cat_idx"
	  
	  create_table "clickthroughs", :force => true do |t|
	  t.column "request_id", :integer, :default => 0, :null => false
	  t.column "service_response_id", :integer, :default => 0, :null => false
	  t.column "created_at", :datetime, :null => false
	  end
	  
	  add_index "clickthroughs", ["request_id"], :name => "click_req_id"
	  add_index "clickthroughs", ["service_response_id"], :name => "click_serv_resp_idx"
	  add_index "clickthroughs", ["created_at"], :name => "click_created_idx"
	  
	  create_table "coverages", :force => true do |t|
	  t.column "journal_id", :integer, :default => 0, :null => false
	  t.column "provider", :string, :default => "", :null => false
	  t.column "coverage", :text
	  end
	  
	  add_index "coverages", ["journal_id"], :name => "cvg_jrnl_id_idx"
	  
	  create_table "dispatched_services", :force => true do |t|
	  t.column "request_id", :integer, :default => 0, :null => false
	  t.column "service_id", :integer, :default => 0, :null => false
	  t.column "successful", :boolean, :default => false, :null => false
	  t.column "updated_at", :datetime, :null => false
	  end
	  
	  add_index "dispatched_services", ["request_id", "service_id"], :name => "dptch_request_id"
	  
	  create_table "institutions", :force => true do |t|
	  t.column "name", :string, :default => "", :null => false
	  t.column "default_institution", :boolean, :default => false, :null => false
	  t.column "worldcat_registry_id", :string, :limit => 25
	  t.column "configuration", :text
	  end
	  
	  add_index "institutions", ["name"], :name => "inst_name"
	  add_index "institutions", ["default_institution"], :name => "inst_dflt_idx"
	  	  
	  create_table "institutions_users", :force => true do |t|
	  t.column "institution_id", :integer, :default => 0, :null => false
	  t.column "user_id", :integer, :default => 0, :null => false
	  t.column "priority", :integer, :default => 0, :null => false
	  end
	  
	  add_index "institutions_users", ["institution_id", "user_id", "priority"], :name => "instuserpri_id"
	  
	  create_table "irrelevant_sites", :force => true do |t|
	  t.column "hostname", :string, :default => "", :null => false
	  end
	  
	  add_index "irrelevant_sites", ["hostname"], :name => "irrev_hostname"
	  
	  create_table "journal_titles", :force => true do |t|
	  t.column "title", :string, :default => "", :null => false
	  t.column "journal_id", :integer, :default => 0, :null => false
	  end
	  
	  add_index "journal_titles", ["title", "journal_id"], :name => "jtitle_title_objects"
	  
	  create_table "journals", :force => true do |t|
	  t.column "object_id", :string, :limit => 20, :default => "", :null => false
	  t.column "title", :string, :default => "", :null => false
	  t.column "normalized_title", :string, :default => "", :null => false
	  t.column "page", :string, :limit => 1, :default => "", :null => false
	  t.column "issn", :string, :limit => 10
	  t.column "eissn", :string, :limit => 10
	  t.column "title_source_id", :integer, :default => 0, :null => false
	  t.column "updated_at", :datetime
	  end
	  
	  add_index "journals", ["object_id"], :name => "j_object_id"
	  add_index "journals", ["normalized_title", "page"], :name => "jrnl_norm_title"
	  add_index "journals", ["title_source_id"], :name => "jrnl_title_source_id"
	  add_index "journals", ["title"], :name => "jrnl_title_idx"
	  add_index "journals", ["issn", "eissn"], :name => "jrnl_issn_idx"
	  add_index "journals", ["updated_at"], :name=>"jrnl_tstamp_idx"  
	  
	  create_table "keywords", :force => true do |t|
	  t.column "term", :string, :default => "", :null => false
	  t.column "keyword_type", :string, :default => "", :null => false
	  end
	  
	  add_index "keywords", ["term", "keyword_type"], :name => "kwd_term_idx"
	  
	  
	  create_table "referent_values", :force => true do |t|
	  t.column "referent_id", :integer, :default => 0, :null => false
	  t.column "key_name", :string, :limit => 50, :default => "", :null => false
	  t.column "value", :text, :default => ""
	  t.column "normalized_value", :string
	  t.column "metadata", :boolean, :default => false, :null => false
	  t.column "private_data", :boolean, :default => false, :null => false
	  end
	  
	  add_index "referent_values", ["referent_id", "key_name", "normalized_value"], :name => "rft_val_referent_idx"
	  
	  create_table "referents", :force => true do |t|
	  t.column "atitle", :string, :limit => 255
	  t.column "title", :string, :limit => 255
	  t.column "issn", :string, :limit => 10
	  t.column "isbn", :string, :limit => 13    
	  t.column "year", :string, :limit => 4
	  t.column "volume", :string, :limit => 10    
	  end
	  
	  add_index "referents", ["atitle", "title", "issn", "isbn", "year", "volume"], :name => 'rft_shortcut_idx'
	  
	  create_table "referrers", :force => true do |t|
	  t.column "identifier", :string, :default => "", :null => false
	  end
	  
	  add_index "referrers", ["identifier"], :name => "rfr_id_idx"
	  
	  create_table "relevant_sites", :force => true do |t|
	  t.column "hostname", :string, :default => "", :null => false
	  t.column "type", :string, :limit => 25
	  end
	  
	  add_index "relevant_sites", ["hostname"], :name => "rel_hostname"
	  
	  create_table "requests", :force => true do |t|
	  t.column "session_id", :string, :limit => 100, :default => "", :null => false
	  t.column "referent_id", :integer, :default => 0, :null => false
	  t.column "referrer_id", :integer
	  t.column "created_at", :datetime, :null => false
	  end
	  
	  add_index "requests", ["referent_id", "referrer_id"], :name => "context_object_idx"
	  add_index "requests", ["session_id"], :name => "req_sess_idx"
	  add_index "requests", ["created_at"], :name => "req_created_at"
	  
	  create_table "service_responses", :force => true do |t|
	  t.column "service_id", :string, :limit=> 25, :null => false
	  t.column "response_key", :string, :limit => 100, :default => "", :null => false
	  t.column "value_string", :string, :limit => 255
	  t.column "value_alt_string", :string, :limit => 255
	  t.column "value_text", :text
	  end
	  
	  add_index "service_responses", ["service_id", "response_key", "value_string", "value_alt_string"], :name => "svc_resp_service_id"
	  
	  create_table "service_types", :force => true do |t|
	  t.column "request_id", :integer, :default => 0, :null => false
	  t.column "service_response_id", :integer, :default => 0, :null => false
	  t.column "service_type", :string, :limit => 35, :default => "", :null => false
	  end
	  
	  add_index "service_types", ["request_id", "service_response_id", "service_type"], :name => "svc_type_idx"
	  
	  
	  create_table "sessions", :force => true do |t|
	  t.column "sessid", :string, :limit => 32
	  t.column "data", :text
	  end
	  
	  add_index "sessions", ["sessid"], :name => "sess_sessid_idx"
	  
	  create_table "title_sources", :force => true do |t|
	  t.column "name", :string, :limit => 50, :default => "", :null => false
	  t.column "location", :text, :default => "", :null => false
	  t.column "filename", :text, :default => "", :null => false
	  end
	  
	  create_table "users", :force => true do |t|
	  t.column "username", :string, :limit => 50, :default => "", :null => false
	  t.column "firstname", :string, :limit => 100
	  t.column "lastname", :string, :limit => 100
	  t.column "email", :string
	  end
	  
	  add_index "users", ["username"], :name => "user_username_idx"
	  
	  create_table "permalinks", :force => true do |t|
	  t.column "referent_id", :integer, :default => 0, :null => false
	  t.column "created_on", :date, :null => false
	  end
	  
	  add_index "permalinks", ["referent_id"], :name => "plink_referent_idx"
	  
	  create_table "crossref_lookups", :force => true do |t|
	  t.column "doi", :string, :limit => "100", :default => "", :null => false
	  t.column "created_on", :datetime
	  end
	  add_index "crossref_lookups", ["doi", "created_on"], :name => 'xref_lookup_doi' 

	  
  end

  def self.down
	drop_table :crossref_lookups
	drop_table :permalinks
	drop_table :users
	drop_table :title_sources
	drop_table :sessions
	drop_table :service_types
	drop_table :service_responses
	drop_table :requests
	drop_table :relevant_sites
	drop_table :referrers
	drop_table :referents
	drop_table :referent_values
	drop_table :keywords
	drop_table :journals
	drop_table :journal_titles
	drop_table :irrelevant_sites
	drop_table :institutions_users
	drop_table :institutions
	drop_table :dispatched_services
	drop_table :coverages
	drop_table :clickthroughs
	drop_table :categories_journals
	drop_table :categories	
  end
end
