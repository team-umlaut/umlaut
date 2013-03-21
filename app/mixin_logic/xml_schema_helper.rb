module XmlSchemaHelper
  def self.xml_ns
    {
      "dlf" => "http://diglib.org/ilsdi/1.1",
      "marc" => "http://www.loc.gov/MARC21/slim",
      "daia" => "http://ws.gbv.de/daia/",
      "atom" => "http://www.w3.org/2005/Atom",
      "opensearch" => "http://a9.com/-/spec/opensearch/1.1/"
    }
  end
  def xml_ns ; XmlSchemaHelper.xml_ns ; end

  
  # Meant for use with "dlf_expanded" responses, but really of wide
  # applicability. The input is a list of Nokogiri elements. Each element
  # should contain as children 0-to-N recognized XML schema formats
  # representing holdings data. XML nodes should be properly
  # namespaced. (Cause that's how we'll recognize them.).  Method will
  # Create Umlaut 'holding' ServiceResponses for each one, taking what
  # info it can get from the metadata.
  #
  # Note that when taking from an dlf_expanded doc, this means the
  # the individual xml elements passed in can be dlf:item OR dlf:holdingsrec
  #
  # Recognized metadata formats:
  # * dlf:simpleavailability from namespace: http://diglib.org/ilsdi/1.1
  # * marc holdings, marc:record with type="Holdings" from namespace: http://www.loc.gov/MARC21/slim
  # * daia from namespace: http://ws.gbv.de/daia/
  #
  # Method uses it's own logic for precedence when the same data element
  # is found in multiple places.
  #
  # NOTE: Does NOT add a :url key, caller will want to add that themselves. 
  def xml_to_holdings(xml)
 
    data = {}

    data[:call_number] = xml_choose_first(xml,
      marc_xpath("852", "h"))

    data[:status] = xml_choose_first(xml,    
      "dlf:simpleavailability/dlf:availabilitymsg")
                
    data[:location] = xml_choose_first(xml,
      [ marc_xpath("852", "b"),
        "daia:daia/daia:document/daia:item/daia:department"
      ])
    
    data[:source_name] = data[:collection_str] = xml_choose_first(xml,
      [ marc_xpath(852, "c"),
        "daia:daia/daia:document/daia:item/daia:storage"
      ])

    data[:copy_str] = xml_choose_first(xml, marc_xpath(852, "i"))

    # get coverage strings from mfhd 866, 867, 868
    data[:coverage_str_array] = []    
    xml.xpath("marc:record/marc:datafield[@tag='866' or @tag='867' or @tag='868']", xml_ns).each do |field|
      value = ""  
      value += mfhd_coverage_prefix( field.attributes["tag"].text )
      value +=  field.xpath("marc:subfield[@code='a']", xml_ns).text
      if ( (notes = field.xpath("marc:subfield[@code='z']", xml_ns)).length > 0)
        value += " -- #{notes.text}"
      end
      data[:coverage_str_array] << value
    end    
    data[:coverage_str] = data[:coverage_str_array].join(" ")
    
    data[:notes] = xml.xpath(marc_xpath(852, "z"), xml_ns).collect {|sf| sf.text.to_s}.join("\n")
        
    data[:request_url] = xml_choose_first(xml, "daia:daia/daia:document/daia:item/daia:available/attribute::href")

    if (data[:collection_str].blank? && data[:location].blank? && data[:call_number].blank? )
      data[:collection_str] = xml_choose_first(xml, "dlf:simpleavailability/dlf:location")
    end

    # Add a display_text to be a good generic Umlaut service response
    data[:display_text] = "#{data[:location]} #{data[:collection_str]} #{data[:call_number]} #{data[:copy_str]}"
            
    # edition_str
    return data
  end

  protected
  def marc_xpath(tag, sf_code)
    "marc:record/marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{sf_code}']"
  end
  def xml_choose_first(xml, path_array)
    path_array = [path_array] if path_array.kind_of?(String)
    
    path_array.each do |path|
      candidate = xml.xpath(path, xml_ns)[0]
      unless candidate.nil?
        return candidate.text
      end
    end
    return nil
  end

  # Translates from marc mfhd tags 866, 867, 868 to a prefix label
  def mfhd_coverage_prefix(tag_str)
    { 
      "866" => "",
      "867" => "Supplements: ", 
      "868" => "Indexes: "
    }[tag_str].to_s
  end
  
end
