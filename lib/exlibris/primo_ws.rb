#!/usr/bin/ruby
# Be sure to configure the Primo Back Office with the relevant IPs to enable
# interaction via the X-Services and Web Services
module Exlibris::PrimoWS
  Default_Namespace = "http://www.exlibris.com/primo/xsd/wsRequest"
  Default_SOAP_Action = ""
  require 'soap/rpc/driver'
  require 'rexml/document'
  require 'hpricot'
  # The PrimoWebService constructor accepts arguments of the following forms:  
  #   String method, 
  #   WebServiceParams params, 
  #   String soapaction=nil, 
  #   String base_url_str=Default_Base_Path_Str, 
  #   String namespace=Default_Namespace
  class PrimoWebService < SOAP::RPC::Driver
    attr_accessor :method_name, :param_name, :input
    attr_reader :request, :response, :error
    def initialize(base_url_str, service, namespace, soapaction, method_name, param_name, input)
      endpoint_url = base_url_str + "/PrimoWebServices/services/primo/" + service
      @method_name = method_name
      @param_name = param_name
      @input = input
      super(endpoint_url, namespace, soapaction)
      add_method(method_name, param_name) if !(respond_to? method_name)
    end
    
    def request
      return @method_name + "(\"" + @input.to_s + "\")"
    end

    def response
      return @response unless @response.nil?
      response_str = eval request
      @response = Hpricot.XML(response_str)
      response
    end
    
    def error
      return @error if @error.kind_of? Array
      @error = []
      response.search("ERROR").each do |e|
        @error.push(e.attributes["MESSAGE"]) unless e.nil?
      end
     error   
    end
  end

  #TODO: make class constructor "smarter" 
  #TODO: enhance error handling 
  class Search < PrimoWebService
    Service = "searcher"
    Input_Namespace = "http://www.exlibris.com/primo/xsd/wsRequest"
    def initialize(method_name, param_name, input_root, ip, institution, group, on_campus, primo_search_request, additional_input, base_url_str, namespace, soapaction)
      service = Service
      input = WebServiceInput.new(input_root)
      input.add_namespace(Input_Namespace)
      input.add_element_with_text("ip", ip) if !ip.nil?
      input.add_element_with_text("institution", institution) if !institution.nil?
      input.add_element_with_text("group", group) if !group.nil?
      input.add_element_with_text("onCampus", on_campus) if !on_campus.nil?
      input.add_element(primo_search_request)
      additional_input.each_element do |e|  
        input.add_element(e)
      end
      super(base_url_str, service, namespace, soapaction, method_name, param_name, input)
    end
  end

  #TODO: make class constructor "smarter"
  # Get results based on a PrimoSearchRequest 
  class SearchBrief < Search
    Method_Name = "searchBrief"
    Param_Name = "searchBriefRequest"
    Input_Root = "searchRequest"
    def initialize(primo_search_request, base_url_str, ip=nil, institution=nil, group=nil, on_campus=nil, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      super(Method_Name, Param_Name, Input_Root, ip, institution, group, on_campus, primo_search_request, additional_input, base_url_str, namespace, soapaction)
    end
  end
        
  # Get record based on doc id
  class GetRecord < Search
    Method_Name = "getRecord"
    Param_Name = "getRecordRequest"
    Input_Root = "fullViewRequest"
    def initialize(doc_id, base_url_str, ip=nil, institution=nil, group=nil, on_campus=nil, primo_search_request=PrimoSearchRequest.new(), namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("docId", doc_id)
      super(Method_Name, Param_Name, Input_Root, ip, institution, group, on_campus, primo_search_request, additional_input, base_url_str, namespace, soapaction)
    end
  end
        
  #TODO: make class constructor "smarter" 
  #TODO: enhance error handling 
  class GetIt < PrimoWebService
    Service = "getIt"
    Input_Namespace = "http://www.exlibris.com/primo/xsd/wsRequest"
    def initialize(method_name, param_name, input_root, institution, is_logged_in, on_campus, group, pds_handle, additional_input, base_url_str, namespace, soapaction)
      service = Service
      input = WebServiceInput.new(input_root)
      input.add_namespace(Input_Namespace)
      input.add_element_with_text("institution", institution) if !institution.nil?
      input.add_element_with_text("isLoggedIn", is_logged_in) if !is_logged_in.nil?
      input.add_element_with_text("onCampus", on_campus) if !on_campus.nil?
      input.add_element_with_text("group", group) if !group.nil?
      input.add_element_with_text("pdsHandle", pds_handle) if !pds_handle.nil?
      additional_input.each_element do |e|  
        input.add_element(e)
      end
      super(base_url_str, service, namespace, soapaction, method_name, param_name, input)
    end
  end

  # Get it url based on doc id
  class GetItURL < GetIt
    Method_Name = "getGetItUrl"
    Param_Name = "getGetItUrlRequest"
    Input_Root = "getItRequest"
    def initialize(doc_id, base_url_str, institution=nil, is_logged_in=nil, on_campus=nil, group=nil, pds_handle=nil, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("docId", doc_id)
      super(Method_Name, Param_Name, Input_Root, institution, is_logged_in, on_campus, group, pds_handle, additional_input, base_url_str, namespace, soapaction)
    end
  end
      
  #TODO: make class constructor "smarter" 
  #TODO: enhance error handling 
  class EShelf < PrimoWebService
    Service = "eshelf"
    Input_Namespace = "http://www.exlibris.com/primo/xsd/wsRequest"
    def initialize(method_name, param_name, input_root, user_id, institution, additional_input, base_url_str, namespace, soapaction)
      service = Service
      input = WebServiceInput.new(input_root)
      input.add_namespace(Input_Namespace)
      input.add_element_with_text("userId", user_id) if !user_id.nil?
      input.add_element_with_text("institution", institution) if !institution.nil?
      additional_input.each_element do |e|  
        input.add_element(e)
      end
      super(base_url_str, service, namespace, soapaction, method_name, param_name, input)
    end
  end

  # Get EShelf based on user_id and institution
  class GetEShelf < EShelf
    Method_Name = "getEshelf"
    Param_Name = "getEshelfRequest"
    Input_Root = "getEshelfRequest"
    def initialize(user_id, institution, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      super(Method_Name, Param_Name, Input_Root, user_id, institution, additional_input, base_url_str, namespace, soapaction)
    end
  end
    
  # Add document to EShelf based on user_id and institution
  class AddToEShelf < EShelf
    Method_Name = "addToEshelf"
    Param_Name = "addToEshelfRequest"
    Input_Root = "addToEshelfRequest"
    def initialize(doc_id, user_id, institution, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("docId", doc_id)
      super(Method_Name, Param_Name, Input_Root, user_id, institution, additional_input, base_url_str, namespace, soapaction)
    end
  end
  
  # Remove document from EShelf based on user_id and institution
  class RemoveFromEShelf < EShelf
    Method_Name = "removeFromEshelf"
    Param_Name = "removeFromEshelfRequest"
    Input_Root = "removeFromEshelfRequest"
    def initialize(doc_id, user_id, institution, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("docId", doc_id)
      super(Method_Name, Param_Name, Input_Root, user_id, institution, additional_input, base_url_str, namespace, soapaction)
    end
  end

  #TODO: make class constructor "smarter" 
  #TODO: enhance error handling 
  class Tags < PrimoWebService
    Service = "tags"
    Input_Namespace = "http://www.exlibris.com/primo/xsd/wsRequest"
    def initialize(method_name, param_name, input_root, additional_input, base_url_str, namespace, soapaction)
      service = Service
      input = WebServiceInput.new(input_root)
      input.add_namespace(Input_Namespace)
      additional_input.each_element do |e|  
        input.add_element(e)
      end
      super(base_url_str, service, namespace, soapaction, method_name, param_name, input)
    end
  end

  # Get Tags based on user_id and doc_id
  class GetTags < Tags
    Method_Name = "getTags"
    Param_Name = "getTagsRequest"
    Input_Root = "getTagsRequest"
    def initialize(user_id, doc_id, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("userId", user_id)
      additional_input.add_element_with_text("docId", doc_id)
      super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
    end
  end
  
  # Get Tags based on user_id
  class GetAllMyTags < Tags
    Method_Name = "getAllMyTags"
    Param_Name = "getAllMyTagsRequest"
    Input_Root = "getAllMyTagsRequest"
    def initialize(user_id, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("userId", user_id)
      super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
    end
  end


  # Get Tags based on doc_id
  class GetTagsForRecord < Tags
    Method_Name = "getTagsForRecord"
    Param_Name = "getTagsForRecordRequest"
    Input_Root = "getTagsForRecordRequest"
    def initialize(doc_id, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("docId", doc_id)
      super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
    end
  end

  # Add Tag based on user_id and doc_id
  class AddTag < Tags
    Method_Name = "addTag"
    Param_Name = "addTagRequest"
    Input_Root = "addTagRequest"
    def initialize(user_id, doc_id, value, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("userId", user_id)
      additional_input.add_element_with_text("docId", doc_id)
      additional_input.add_element_with_text("value", value)
      super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
    end
  end

  # Remove Tag based on user_id and doc_id
  class RemoveTag < Tags
    Method_Name = "removeTag"
    Param_Name = "removeTagRequest"
    Input_Root = "removeTagRequest"
    def initialize(user_id, doc_id, value, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
      additional_input = AdditionalInput.new()
      additional_input.add_element_with_text("userId", user_id)
      additional_input.add_element_with_text("docId", doc_id)
      additional_input.add_element_with_text("value", value)
      super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
    end
  end

#TODO: make class constructor "smarter" 
#TODO: enhance error handling 
class Reviews < PrimoWebService
  Service = "reviews"
  Input_Namespace = "http://www.exlibris.com/primo/xsd/wsRequest"
  def initialize(method_name, param_name, input_root, additional_input, base_url_str, namespace, soapaction)
    service = Service
    input = WebServiceInput.new(input_root)
    input.add_namespace(Input_Namespace)
    additional_input.each_element do |e|  
      input.add_element(e)
    end
    super(base_url_str, service, namespace, soapaction, method_name, param_name, input)
  end
end

# Get Reviews based on user_id and doc_id
class GetReviews < Reviews
  Method_Name = "getReviews"
  Param_Name = "getReviewsRequest"
  Input_Root = "getReviewsRequest"
  def initialize(user_id, doc_id, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
    additional_input = AdditionalInput.new()
    additional_input.add_element_with_text("userId", user_id)
    additional_input.add_element_with_text("docId", doc_id)
    super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
  end
end

# Get Reviews based on user_id
class GetAllMyReviews < Reviews
  Method_Name = "getAllMyReviews"
  Param_Name = "getAllMyReviewsRequest"
  Input_Root = "getAllMyReviewsRequest"
  def initialize(user_id, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
    additional_input = AdditionalInput.new()
    additional_input.add_element_with_text("userId", user_id)
    super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
  end
end


# Get Reviews based on doc_id
class GetReviewsForRecord < Reviews
  Method_Name = "getReviewsForRecord"
  Param_Name = "getReviewsForRecordRequest"
  Input_Root = "getReviewsForRecordRequest"
  def initialize(doc_id, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
    additional_input = AdditionalInput.new()
    additional_input.add_element_with_text("docId", doc_id)
    super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
  end
end

# Get Reviews based on user_id and rating
class GetReviewsByRating < Reviews
  Method_Name = "getReviewsByRating"
  Param_Name = "getReviewsByRatingRequest"
  Input_Root = "getReviewsByRatingRequest"
  def initialize(user_id, rating, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
    additional_input = AdditionalInput.new()
    additional_input.add_element_with_text("userId", user_id)
    additional_input.add_element_with_text("rating", rating)
    super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
  end
end

# Add Review based on user_id and doc_id
class AddReview < Reviews
  Method_Name = "addReview"
  Param_Name = "addReviewRequest"
  Input_Root = "addReviewRequest"
  def initialize(user_id, doc_id, value, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
    additional_input = AdditionalInput.new()
    additional_input.add_element_with_text("userId", user_id)
    additional_input.add_element_with_text("docId", doc_id)
    additional_input.add_element_with_text("value", value)
    super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
  end
end

# Remove Review based on user_id and doc_id
class RemoveReview < Reviews
  Method_Name = "removeReview"
  Param_Name = "removeReviewRequest"
  Input_Root = "removeReviewRequest"
  def initialize(user_id, doc_id, value, base_url_str, namespace=Default_Namespace, soapaction=Default_SOAP_Action)
    additional_input = AdditionalInput.new()
    additional_input.add_element_with_text("userId", user_id)
    additional_input.add_element_with_text("docId", doc_id)
    additional_input.add_element_with_text("value", value)
    super(Method_Name, Param_Name, Input_Root, additional_input, base_url_str, namespace, soapaction)
  end
end

  class WebServiceInput < REXML::Element
    def initialize(root)
      super(root)
    end
    
    def add_element_with_text(name, value)
      e = add_element(name)
      e.add_text(value)
    end
  end
  
  class AdditionalInput < WebServiceInput
    Root = "AdditionalInput"
    def initialize
      super(Root)
    end
  end
  
  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class PrimoSearchRequest < WebServiceInput
    Root = "PrimoSearchRequest"
    Start_Default = "1"
    Bulk_Size_Default = "5"
    DYM_Default = "false"
    Highlighting_Default = "false"
    Get_More_Default = nil
    def initialize(query_terms=QueryTerms.new(), start_index=Start_Default, bulk_size=Bulk_Size_Default, did_u_mean_enabled=DYM_Default, highlighting_enabled=Highlighting_Default, get_more=Get_More_Default, languages=Languages.new(), sort_by_list=SortByList.new(), display_fields=DisplayFields.new(), locations=Locations.new())
      super(Root)
      add_namespace("http://www.exlibris.com/primo/xsd/search/request")
      add_element(query_terms)
      add_element_with_text("StartIndex", start_index) if !start_index.nil?
      add_element_with_text("BulkSize", bulk_size) if !bulk_size.nil?
      add_element_with_text("DidUMeanEnabled", did_u_mean_enabled) if !did_u_mean_enabled.nil?
      add_element_with_text("HighlightingEnabled", highlighting_enabled) if !highlighting_enabled.nil?
      add_element_with_text("GetMore", get_more) if !get_more.nil?
      #add_element(languages)
      #add_element(sort_by_list)
      #add_element(display_fields)
      #add_element(locations)
    end
  end
  
  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class QueryTerms < WebServiceInput
    Root = "QueryTerms"
    Bool_Default = "AND"
    def initialize(query_term=QueryTerm.new(), bool_operator=Bool_Default)
      super(Root)
      add_element_with_text("BoolOpeator", bool_operator) if !bool_operator.nil?
      add_query_term(query_term)
    end
    
    def add_query_term(query_term)
      add_element(query_term)
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class QueryTerm < WebServiceInput
    Root = "QueryTerm"
    def initialize(value=nil, index_field="any", precision_operator="contains")
      super(Root)
      add_element_with_text("IndexField", index_field) if !value.nil?
      add_element_with_text("PrecisionOperator", precision_operator) if !value.nil?
      add_element_with_text("Value", value) if !value.nil?
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class Languages < WebServiceInput
    Root = "Languages"
    def initialize(language=Language.new())
      super(Root)
      add_element(language)
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class Language < WebServiceInput
    Root = "Language"
    Default_Lang = nil
    def initialize(lang=Default_Lang)
      super(Root)
      add_text(lang) if !lang.nil?
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class SortByList < WebServiceInput
    Root = "SortByList"
    def initialize(sort_field=SortField.new())
      super(Root)
      add_element(sort_field)
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class SortField < WebServiceInput
    Root = "SortField"
    Default_Sort_Field = nil
    def initialize(sort_field=Default_Sort_Field)
      super(Root)
      add_text(sort_field) if !sort_field.nil?
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class DisplayFields < WebServiceInput
    Root = "DisplayFields"
    def initialize(display_field=DisplayField.new())
      super(Root)
      #add_element(display_field)
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class DisplayField < WebServiceInput
    Root = "DisplayField"
    Default_Display_Field = nil
    def initialize(display_field=Default_Display_Field)
      super(Root)
      add_text(display_field) if !display_field.nil?
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class Locations < WebServiceInput
    Root = "Locations"
    def initialize(location=Location.new())
      super(Root)
      add_element(location)
    end
  end

  #TODO: make class constructor "smarter"
  #TODO: enhance error handling 
  class Location < WebServiceInput
    Root = "Location"
    Default_Location = ""
    def initialize(location=Default_Location)
      super(Root)
      add_namespace("http://www.exlibris.com/primo/xsd/primoview/uicomponents")
      add_attribute("type", "local")
      add_attribute("value", location)
    end
  end
end
  