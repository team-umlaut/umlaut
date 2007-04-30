module FeedTools
  class OpensearchQuery
    def initialize(role='request', attributes={})
      @role = self.role=role
      @title = nil
      @search_terms = nil
      @total_results = nil
      @count = nil
      @start_index = nil
      @start_page = nil
      @language = nil
      @input_encoding = nil
      @output_encoding = nil
      attributes.each { | key, val |
        next unless val
        iv = "@"+key.to_s
        self.instance_variable_set(iv.to_sym, val) if self.instance_variables.index(iv)
      }
    end
    def role
      return @role
    end
    def role=(role)
      roles = ["request","example","related","correction","subset","superset"]
      raise(ArgumentError, "Must be a valid role") unless roles.index(role)
      @role=role
    end
    def title
      return @title
    end
    def title=(title)
      @title=title
    end
    def search_terms
      return @search_terms
    end
    def search_terms=(search_terms)
      @search_terms=search_terms
    end
    def total_results
      return @total_results
    end
    def total_results=(total_results)
      @total_results=total_results
    end
    def count
      return @count
    end
    def count=(count)
      @count=count
    end
    def start_index
      return @start_index
    end
    def start_index=(start_index)
      @start_index=start_index
    end
    def start_page
      return @start_page
    end
    def start_page=(start_page)
      @start_page=start_page
    end
    def language
      return @language
    end
    def language=(lang)
      @language=lang
    end
    def input_encoding
      return @input_encoding
    end
    def input_encoding=(ip)
      @input_encoding=ip
    end
    def output_encoding
      return @output_encoding
    end
    def output_encoding=(op)
      @output_encoding=op
    end
    def build_xml(xml)
      attrs = {}
      attrs[:role]=@role if @role
      attrs[:title]=@title if @title
      attrs[:count]=@count if @count
      attrs[:language]=@language if @language
      attrs[:searchTerms]=@search_terms if @search_terms
      attrs[:startIndex]=@start_index if @start_index
      attrs[:startPage]=@start_page if @start_page
      attrs[:inputEncoding]=@input_encoding if @input_encoding
      attrs[:outputEncoding]=@output_encoding if @output_encoding      
      attrs[:totalResults]=@total_results if @total_results
      xml.tag!("opensearch:Query", attrs)
    end
  end

end