module EmailerHelper
  include ApplicationHelper
  
  # returns a plain text short citation
  def brief_citation(request, options = {})

    debugger
    
    options[:include_labels] ||= false

    rv =""
    
    
    cite = request.referent.to_citation 

    rv << (cite[:title_label].strip + ": ")if options[:include_labels]
    rv << cite[:title].strip
    rv << "\n"
    
    if cite[:author]  
      rv << "Author: " if options[:include_labels]
      rv << cite[:author].strip
      rv << "\n"
    end
    if cite[:subtitle]
      rv << (cite[:subtitle_label].strip + ": ") if options[:include_labels]
      rv << cite[:subtitle].strip
      rv << "\n"
    end

    pub = []
    pub << date_format(cite[:date]) unless cite[:date].blank?	
    pub << 'Volume: '+cite[:volume].strip unless cite[:volume].blank?
    pub << 'Issue: '+cite[:issue].strip unless cite[:issue].blank?	
    pub << 'Page: '+cite[:page].strip unless cite[:page].blank?
    if pub.length > 0
      rv << "Published: " if options[:include_labels]
      rv << pub.join('  ')
    end
    
    return rv  
  end
end
