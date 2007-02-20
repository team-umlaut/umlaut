class OpenworldcatClient

  def make_interesting(link, context_object)
    return {:highlighted_link=>{:type => "worldcat", :title =>"View record in OpenWorldcat",:url => link[:url]}}
  end
end