require 'oai'

buffer = ""
start_time = Time.now()

client = OAI::Client.new 'http://digitalcollections.library.oregonstate.edu/cgi-bin/oai.exe', :parser =>'libxml'

last_check = Date.new(2006,9,5)
records = client.list_records
# :set => 'archives', :metadata_prefix => 'oai_dc', :from => last_check 

x = 0
records.each do |record|
  #fields = record.serialize_metadata(record.metadata, "oai_dc", "Oai_Dc")
  #puts "Primary Title: " + fields.title[0] + "\n"
  puts "Identifier: " +  record.header.identifier + "\n"
  x += 1
end

end_time = Time.now()

puts buffer
puts "Time to run: " + (end_time - start_time).to_s + "\n"
puts "Records returned: " + x.to_s

