# register an email address at: http://www.journaltocs.ac.uk/index.php?action=register

class JournalTocsController < UmlautController
  
  def show
    @issn  = params["rft.issn"] || params["issn"]
    
    if @issn.blank?
      render :status => 500, :text => "Client must supply an ISSN"
      return
    end
    
    @title = params["rft.title"] || params["title"]
     
    fetcher = JournalTocsFetcher.new(@issn)
    
    @results = fetcher.items
    
    if @results.empty?
      render :status => 404, :text => "No current articles available for #{@title} #{@issn}"
      return
    end
    
    respond_to do |format|
      format.html # journal_tocs/show.html.erb
      format.atom do
        render( :template => "bento_search/atom_results",              
                :locals   => {
                  :atom_results     => @results,
                  :feed_name        => "Recent Articles from #{@title || @issn}",
                  :feed_author_name => "MyCorp"
              }      
        )
      end 
    end
    
  end
  
  
  
  
  
  
end

