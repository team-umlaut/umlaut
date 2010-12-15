require 'nokogiri'

module SearchMethods
  module Sfx4
    include MetadataHelper # for normalize_lccn
    
    protected
    
    # Needs to return ContextObjects
    def find_by_title                  
      connection = sfx4_db_connection
  
        
      query_match_clause = case search_type_param
        when "contains"
          "MATCH (TS.TITLE_SEARCH) AGAINST ('+#{connection.quote_string(title_query_param)}*' IN BOOLEAN MODE)"
        when "begins"
          "TS.TITLE_SEARCH LIKE '#{connection.quote_string(title_query_param)}%'"
        else # exact
          "TS.TITLE_SEARCH = '#{connection.quote_string(title_query_param)}'"
        end.upcase
        
      from_where_clause = %{
        FROM 
          AZ_TITLE T, AZ_TITLE_SEARCH TS 
        WHERE 
          TS.AZ_TITLE_ID = T.AZ_TITLE_ID AND 
          #{query_match_clause} AND 
          T.AZ_PROFILE = '#{connection.quote_string(sfx_az_profile)}'       
      } 
      
      statement = %{
        SELECT 
          DISTINCT T.OBJECT_ID 
        #{from_where_clause}
        ORDER BY 
          T.SCRIPT DESC, T.TITLE_SORT
        LIMIT #{batch_size.to_i}
        OFFSET #{(batch_size * (page - 1)).to_i}
        }

      # do the count  
      total_hits = SfxDb::Object.count_by_sql(
          "SELECT COUNT(*) #{from_where_clause}"
      )
      
                       
      object_ids = connection.select_all(statement).collect {|i| i.values.first}
                  
      sql = SfxDb::Object.send(:sanitize_sql_array,
        [%{
           SELECT 
              EI.OBJECT_ID, T.TITLE_DISPLAY, EI.EXTRA_INFO_XML 
           FROM 
              AZ_TITLE T 
              JOIN AZ_EXTRA_INFO EI 
                ON (EI.OBJECT_ID = T.OBJECT_ID AND EI.AZ_PROFILE = T.AZ_PROFILE)
           WHERE
              T.AZ_PROFILE=?
              AND EI.OBJECT_ID IN (?)
           ORDER BY 
              T.SCRIPT DESC, T.TITLE_SORT
          }, 
          sfx_az_profile, 
          object_ids])
      
      title_objects =  connection.select_all(sql)
            
      # Make em into context objects
      context_objects = title_objects.collect do |sfx_obj|
        ctx = OpenURL::ContextObject.new
        # Start out wtih everything in search, to preserve date/vol/etc
        ctx.import_context_object( context_object_from_params )        
        
        extra_info_xml = Nokogiri::XML( sfx_obj["EXTRA_INFO_XML"] )
        
        # Put SFX object id in rft.object_id, that's what SFX does. 
        ctx.referent.set_metadata('object_id', sfx_obj["OBJECT_ID"])
        ctx.referent.set_metadata("jtitle", sfx_obj["TITLE_DISPLAY"] || "Unknown Title")
        
        issn = extra_info_xml.search("item[key=issn]").text
        isbn =  extra_info_xml.search("item[key=isbn]").text
        lccn = extra_info_xml.search("item[key=lccn]").text
        
        ctx.referent.set_metadata("issn", issn ) unless issn.blank?
        ctx.referent.set_metadata("isbn", isbn) unless isbn.blank?
        ctx.referent.add_identifier("info:lccn/#{normalize_lccn(lccn)}") unless lccn.blank?      
        
        ctx
      end
      return [context_objects, total_hits]
    end
    
    # Used for clicks on A, B, C, 0-9, etc. 
    def find_by_group
      connection = sfx4_db_connection
      from_where_clause = %{
           FROM 
              AZ_TITLE T 
              JOIN AZ_EXTRA_INFO EI 
                ON (EI.OBJECT_ID = T.OBJECT_ID AND EI.AZ_PROFILE = T.AZ_PROFILE)
              JOIN AZ_LETTER_GROUP 
                ON (T.AZ_TITLE_ID = AZ_LETTER_GROUP.AZ_TITLE_ID) 
           WHERE
              T.AZ_PROFILE= '#{connection.quote_string(sfx_az_profile)}'          
              AND #{sfx4_quoted_letter_group_condition}
          }
      count_sql = %{
        SELECT count(*)
        
        #{from_where_clause}
      }
      
      fetch_sql = %{
           SELECT 
              EI.OBJECT_ID, T.TITLE_DISPLAY, EI.EXTRA_INFO_XML
              
            #{from_where_clause}
            
           ORDER BY 
             T.SCRIPT DESC, T.TITLE_SORT
           LIMIT #{batch_size.to_i}
           OFFSET #{(batch_size * (page - 1)).to_i}      
      }
          
      total_count = SfxDb::Object.count_by_sql( count_sql )
      context_objects = sfx4_db_to_ctxobj( connection.select_all(fetch_sql) )

      return [context_objects, total_count]
    end
    
    def sfx4_db_connection
      SfxDb::Object.connection
    end
    
    def sfx4_quoted_letter_group_condition
      " AZ_LETTER_GROUP.AZ_LETTER_GROUP_NAME " +
      case params[:id]
      when "0-9"
        " IN ('0','1','2','3','4','5','6','7','8','9')"
      when /^Other/i
        "= 'Others'"
      else
        "= '#{sfx4_db_connection.quote_string(params[:id].upcase)}'"
      end
    end
    
    def sfx4_db_to_ctxobj(title_rows)
      title_rows.collect do |sfx_obj|
        ctx = OpenURL::ContextObject.new
        # Start out wtih everything in search, to preserve date/vol/etc
        ctx.import_context_object( context_object_from_params )        
        
        extra_info_xml = Nokogiri::XML( sfx_obj["EXTRA_INFO_XML"] )
        
        # Put SFX object id in rft.object_id, that's what SFX does. 
        ctx.referent.set_metadata('object_id', sfx_obj["OBJECT_ID"])
        ctx.referent.set_metadata("jtitle", sfx_obj["TITLE_DISPLAY"] || "Unknown Title")
        
        issn = extra_info_xml.search("item[key=issn]").text
        isbn =  extra_info_xml.search("item[key=isbn]").text
        lccn = extra_info_xml.search("item[key=lccn]").text
        
        ctx.referent.set_metadata("issn", issn ) unless issn.blank?
        ctx.referent.set_metadata("isbn", isbn) unless isbn.blank?
        ctx.referent.add_identifier("info:lccn/#{normalize_lccn(lccn)}") unless lccn.blank?      
        
        ctx
      end
      
    end
    
  end
end

