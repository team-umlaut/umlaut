require 'nokogiri'
module SearchMethods
  module Sfx4
    include MetadataHelper # for normalize_lccn

    protected
    # Class method for the module that gets called by the umlaut:load_sfx_urls task.
    # Determines whether we should attempt to fetch SFX urls.
    # Will probably be deprecated in the near future.
    def self.fetch_urls?
      sfx4_base.connection_configured?
    end

    # Class method for the module that gets called by the umlaut:load_sfx_urls task.
    # Kind of hacky way of trying to extract target URLs from SFX4.
    # Will probably be deprecated in the near future.
    def self.fetch_urls
      sfx4_base.fetch_urls
    end
    
    # Class method for the module.
    # Returns the SFX4 base class in order to establish a connection.
    def self.sfx4_base
      # Need to do this convoluted Module.const_get so that we find the
      # correct class. Otherwise the module looks locally and can't find it.
      Module.const_get(:Sfx4).const_get(:Local).const_get(:Base)
    end

    # Instance method that returns the SFX4 AzTitle class for this search method.
    # Can be overridden by search methods that want to include this one.
    def az_title_klass
      # Need to do this convoluted Module.const_get so that we find the
      # correct class. Otherwise the module looks locally and can't find it.
      Module.const_get(:Sfx4).const_get(:Local).const_get(:AzTitle)
    end

    # Instance method that returns the SFX4 DB connection for this search method.
    def sfx4_db_connection
      az_title_klass.connection
    end

    # Needs to return ContextObjects
    def find_by_title
      connection = sfx4_db_connection
      query_match_clause = case search_type_param
        when "contains"
          terms = title_query_param.split(" ")
          #SFX4 seems to ignore 'the' or 'a' on the front, so we will too. 
          if (["the", "a"].include? terms[0])
            terms = terms.slice(1..-1)
          end
          # Then make each term required, but stemmed. Seems to match SFX4, 
          # and more importantly give us decent results. 
          #
          # For reasons we can't entirely tell, the wildcard "*" on terms of less
          # than 2 causes false negatives. Otherwise we use it to be consistent
          # with SFX. This reverse-engineering is full of pitfalls.
          query = terms.collect do |term|
            "+" + connection.quote_string(term) + (term.length > 2 ? "*" : "")
          end.join(" ")
          "MATCH (TS.TITLE_SEARCH) AGAINST ('#{query}' IN BOOLEAN MODE)"
        when "begins"
          # For 'begins', searching against TITLE itself rather than TITLE_SEARCH gives us 
          # results more like SFX4 native, without so many 'also known as' titles confusing
          # things.           
          "(T.TITLE_DISPLAY LIKE '#{connection.quote_string(title_query_param)}%' OR T.TITLE_SORT LIKE '#{connection.quote_string(title_query_param)}%')"
          #"TS.TITLE_SEARCH LIKE '#{connection.quote_string(title_query_param)}%'"
        else # exact
          "( TS.TITLE_SEARCH = '#{connection.quote_string(title_query_param)}' OR 
             T.TITLE_DISPLAY = '#{connection.quote_string(title_query_param)}' OR
             T.TITLE_SORT = '#{connection.quote_string(title_query_param)}'
           )"                        
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
      total_hits = az_title_klass.count_by_sql(
          "SELECT COUNT(DISTINCT(T.OBJECT_ID)) #{from_where_clause}")
      object_ids = connection.select_all(statement).collect {|i| i.values.first}
      sql = az_title_klass.send(:sanitize_sql_array,
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
          sfx_az_profile, object_ids])
      title_objects =  connection.select_all(sql)
      # Make em into context objects
      context_objects = title_objects.collect do |sfx_obj|
        ctx = OpenURL::ContextObject.new
        # Start out wtih everything in search, to preserve date/vol/etc
        ctx.import_context_object( context_object_from_params )        
        extra_info_xml = Nokogiri::XML( sfx_obj["EXTRA_INFO_XML"] )
        # Put SFX object id in rft.object_id, that's what SFX does.
        ctx.referent.set_metadata('object_id', sfx_obj["OBJECT_ID"].to_s )
        ctx.referent.set_metadata("jtitle", sfx_obj["TITLE_DISPLAY"] || "Unknown Title")
        issn = extra_info_xml.search("item[key=issn]").text
        isbn =  extra_info_xml.search("item[key=isbn]").text
        # LCCN is stored corrupted in xml in SFX db, without prefix like "sn" that
        # is a significant part of lccn. Our reverse engineering of SFX failed,
        # apparently there's a workaround in SFX app code. Forget it, bail
        # don't try to use lccn. 
        #lccn = extra_info_xml.search("item[key=lccn]").text
        ctx.referent.set_metadata("issn", issn ) unless issn.blank?
        ctx.referent.set_metadata("isbn", isbn) unless isbn.blank?
        #ctx.referent.add_identifier("info:lccn/#{normalize_lccn(lccn)}") unless lccn.blank?      
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
      total_count = az_title_klass.count_by_sql( count_sql )
      context_objects = sfx4_db_to_ctxobj( connection.select_all(fetch_sql) )
      return [context_objects, total_count]
    end

    def sfx4_quoted_letter_group_condition
      " AZ_LETTER_GROUP.AZ_LETTER_GROUP_NAME " + case params[:id]
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
