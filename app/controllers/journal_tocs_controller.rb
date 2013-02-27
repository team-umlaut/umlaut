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
    
    # direct to use our custom decorator
    @results.each {|r| r.decorator = "JournalTocsController::ArticleDecorator" }
    

    
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
  
  # A article decorator from BentoSearch, where we customize our links:
  # If we have enough info for an OpenURL, do a self-pointing OpenURL
  # to us, set with redirect to fulltext. If there is not enough info
  # for an openurl, no link at all at present. 
  #
  # Possible enhancements: Refworks link. Find It link without auto redirect. 
  #   link to publisher link if it's open access?
  #   link to publisher link through ezproxy even if it's not, on a wing and a prayer?
  class ArticleDecorator < BentoSearch::StandardDecorator
    def link
      if sufficient_for_openurl?
        _h.resolve_url + "?#{self.to_openurl_kev}&umlaut.skip_resolve_menu_for_type=fulltext"
      else
        nil
      end
    end
    
    def sufficient_for_openurl?
      doi.present? || (issn.present? && volume.present? && issue.present? && number.present? && start_page.present?)
    end
    
    # We don't want to display format
    def display_format
      nil
    end
    
  end
  
  
  
  
  
end

