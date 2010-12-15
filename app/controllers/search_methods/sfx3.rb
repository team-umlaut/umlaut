module SearchMethods
  module Sfx3      
    
    protected
    
    #returns pair of 1) array of context object results for current page, 2) hit count
    def find_by_title
      (object_ids, hit_count) = object_ids_az_v3(title_query_param, search_type_param, batch_size, page )
      
      # Now fetch objects with publication information
      # Sometimes SFX db lacks referential integrity, so we don't count
      # on these object_ids actually being there, doing a find all instead
      # of just a 'find'. 
      sfx_objects = SfxDb::Object.find( :all, :conditions => {:OBJECT_ID => object_ids},
      :include => [:publishers, :main_titles, :primary_issns, :primary_isbns])
      
      # We got the right set of @batch_size objects, but they're not sorted
      # by title. 
      # Too hard to include the sort in the SQL, let's re-sort in memory
      sfx_objects.sort! do |a,b| 
        if (a.main_titles.first && b.main_titles.first)
          a.main_titles.first.TITLE_DISPLAY <=> b.main_titles.first.TITLE_DISPLAY
        else
          0
        end
      end
      
      # Now we need to convert to ContextObjects.
      context_objects = sfx_objects.collect do |sfx_obj|
        ctx = OpenURL::ContextObject.new
        # Start out with everything in the search, to preserve date/vol info
        ctx.import_context_object( context_object_from_params )
  
        # Put SFX object id in rft.object_id, that's what SFX does. 
        ctx.referent.set_metadata('object_id', sfx_obj.id.to_s)
  
        publisher_obj = sfx_obj.publishers.first
        if ( publisher_obj )
          ctx.referent.set_metadata('pub', publisher_obj.PUBLISHER_DISPLAY)
          ctx.referent.set_metadata('place', publisher_obj.PLACE_OF_PUBLICATION_DISPLAY)
        end
        
        title_obj = sfx_obj.main_titles.first
        title = title_obj ? title_obj.TITLE_DISPLAY : "Unknown Title"
        ctx.referent.set_metadata('jtitle', title)
  
        issn_obj = sfx_obj.primary_issns.first
        ctx.referent.set_metadata('issn', issn_obj.ISSN_ID) if issn_obj
  
        isbn_obj = sfx_obj.primary_isbns.first     
        ctx.referent.set_metadata('isbn', isbn_obj.ISBN_ID) if isbn_obj
        
        ctx
      end
      return [context_objects, hit_count]
    end
    

  
  # Object Ids from SFX A-Z list 'version 3'. The A-Z v3 title list
  # is cranky, so we have a v2 version too. 
  # input title query, search_type
  # Returns an array [ batch_obj_id_array, count ]. 
  def object_ids_az_v3(title_q, search_type, batch_size, page)
    # MySQL 'like' is case-insensitive, fortunately, don't need to worry
    # about that. But to deal with non-filing chars, need to search against
    # TITLE_DISPLAY and TITLE_SORT for begins with. We're going to join
    # to AZ_TITLE_SEARCH_VER3 for alternate titles too. 
    conditions = case search_type
      when 'contains'
        ['ts.AZ_PROFILE = ? AND TITLE_DISPLAY like ? OR ts.TITLE_SEARCH like ?',
        sfx_az_profile,
        "%" + title_q.upcase + "%", "%" + title_q.upcase + "%"]
      when 'begins'
       ['ts.AZ_PROFILE = ? AND TITLE_DISPLAY like ? OR TITLE_SORT like ? OR ts.TITLE_SEARCH like ?',
       sfx_az_profile,
       title_q + '%', title_q + '%', title_q + "%"]
      else # exact
        ['ts.AZ_PROFILE = ? AND TITLE_DISPLAY = ? OR TITLE_SORT =  ? OR ts.TITLE_SEARCH = ?', 
        sfx_az_profile,
        title_q, title_q, title_q]
    end
    
    # First get object_ids we're interested in, then
    # we'll bulk fetch with all their data. 
    # Tricky-ass query for efficiency and power, sorry.
    joins = "left outer join AZ_TITLE_SEARCH_VER3 as ts on  `AZ_TITLE_VER3`.AZ_TITLE_VER3_ID = ts.AZ_TITLE_VER3_ID"

    
    # Actually, _first_ we'll do a total count.
    total_hits = SfxDb::AzTitle.count(:OBJECT_ID, 
    :distinct=>true,
    :conditions=>conditions,
    :joins=>joins,
    :order=>'TITLE_SORT ASC')

    # Now fetch object_ids for just the display batch
    object_ids = SfxDb::AzTitle.find(:all, :select=>"distinct (OBJECT_ID)",
    :conditions => conditions, 
    :joins => joins,
    :limit => batch_size,
    :offset => batch_size * (page - 1),
    :order=>'TITLE_SORT ASC').collect { |title_obj| title_obj.OBJECT_ID}


    return [ object_ids, total_hits]
  end

  # params[:id] will have a capital letter, or "0-9" or "Other"
  def find_by_group
    
      joins = " inner join AZ_LETTER_GROUP_VER3 as lg on AZ_TITLE_VER3.AZ_TITLE_VER3_ID = lg.AZ_TITLE_VER3_ID"
      # Need a special condition for 0-9
      if ( params[:id] == '0-9')
        conditions = ["AZ_PROFILE=? AND lg.AZ_LETTER_GROUP_VER3_NAME IN ('0','1','2','3','4','5','6','7','8','9')",
        sfx_az_profile]
      else
        conditions = ["AZ_PROFILE=? AND lg.AZ_LETTER_GROUP_VER3_NAME = ?", 
        sfx_az_profile,
        params[:id].upcase]
      end

      hits = SfxDb::AzTitle.count(:joins => joins,
            :conditions => conditions)


      # Sorry this find is so crazy, trying to manage to do it
      # efficiently and get what we need in large SFX db. 
      # For crazy nested include below, see:
      # http://snippets.dzone.com/posts/show/2089
      az_titles = SfxDb::AzTitle.find(:all, 
        :joins => joins,
        :conditions => conditions,
        :limit => batch_size,
        :offset=> batch_size * (page - 1),
        :order=>'TITLE_SORT',
        :include=>[{:object => [:publishers, :titles] }])
        
      # Convert to context objects
      display_results = az_titles.collect do | azt | 
        co = azt.to_context_object
        co.referrer.add_identifier('info:sid/umlaut.code4lib.org:azlist')
        co
      end
      return [display_results, hits]
    end
  end
end
