class ArxivClient

  def make_interesting(link, context_object)
    return {:fulltext_link=>{:type => "arXiv", :source=>'ArXiv.org', :source_id=>nil, :display_text =>"arXiv.org",:url => link[:url]}}
  end
end