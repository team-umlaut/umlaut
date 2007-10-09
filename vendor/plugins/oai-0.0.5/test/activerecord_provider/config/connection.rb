# Configure AR connection
conn_info = YAML.load_file(
  File.join(File.dirname(__FILE__), "database.yml")
)
ActiveRecord::Base.establish_connection(conn_info)