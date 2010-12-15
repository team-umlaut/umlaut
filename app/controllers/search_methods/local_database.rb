module SearchMethods
  # NOT WORKING, just a rough sketch of a search method that would use a local
  # 'index' of titles from the app rdbms.  This would be a nice thing to be able
  # to do, but we haven't done it yet, this code is mostly just here for archival
  # purposes, is from before several refactors of Umlaut, will definitely no
  # longer work as is, but may be useful to someone wanting to take another
  # crack at it. 
  module LocalDatabase
    
      # This isn't working right now. It needs to be fixed up quite a bit.
      # Should use the instance variables defined in journal_search,
      # and do a 'count' search, putting results in @hits, putting
      # just the current batch in @display_results. 
      def find_by_title
        offset = batch_size * (page - 1)
        
        unless session[:search] == {:title_search=>params['sfx.title_search'], :title=>params['rft.jtitle']}
          session[:search] = {:title_search=>params['sfx.title_search'], :title=>params['rft.jtitle']}
    
          titles = case params['sfx.title_search']    
            when 'begins'          
              Journal.find(:all, :conditions=>['lower(title) LIKE ?', params['rft.jtitle'].downcase+"%"], :offset=>offset, :limit=>@batch_size)
            else
              qry = params['rft.jtitle']
              qry = '"'+qry+'"' if qry.match(/\s/)        
              options = {:limit=>@batch_size, :offset=>offset}
              Journal.find_by_contents('alternate_titles:'+qry, options)         
            end
          
          ids = []
          titles.each { | title |
            ids << title.journal_id
          }   
          session[:search_results] = ids.uniq
        end
        total_count = session[:search_results].length
        if params[:page]
          start_idx = (params[:page].to_i*10-10)
        else
          start_idx = 0
        end
        if session[:search_results].length < start_idx + 9
          end_idx = (session[:search_results].length - 1)
        else 
          end_idx = start_idx + 9
        end
        search_results = []
        if session[:search_results].length > 0
          Journal.find(session[:search_results][start_idx..end_idx]).each {| journal |
            co = OpenURL::ContextObject.new
            # import the search criteria, so we can pass em on
            co.import_context_object( @search_context_object )
            
            co.referent.set_metadata('jtitle', journal.title)
            unless journal.issn.blank?
              co.referent.set_metadata('issn', journal.issn)
            end
            co.referent.set_format('journal')
            co.referent.set_metadata('genre', 'journal')
            co.referent.set_metadata('object_id', journal[:object_id].to_s)
            search_results << co
          }
        end
        return [search_results, total_count]
      end
    
  end
end
