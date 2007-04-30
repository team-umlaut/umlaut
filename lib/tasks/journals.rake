namespace :journals do
  task :reload_journals => :environment do
    Journal.delete_all
    JournalTitle.delete_all
    Category.delete_all
#    ActiveRecord::Base.connection.execute('TRUNCATE TABLE categories')
#    ActiveRecord::Base.connection.execute('TRUNCATE TABLE categories_journals')
#    ActiveRecord::Base.connection.execute('TRUNCATE TABLE coverages')
#    ActiveRecord::Base.connection.execute('TRUNCATE TABLE journals')
#    ActiveRecord::Base.connection.execute('TRUNCATE TABLE journal_titles')

    FileUtils.rm_r('index', :force=>true)
    
    TitleSource.find(:all).each { | source |
      require 'rubyful_soup'
      uri = URI::parse(source.location)
      http = Net::HTTP.new(uri.host, uri.port)  
      http_response = http.get(uri.path)    
      if source.id == 2
        soup = BeautifulSoup.new(http_response.body)
        git = soup.find_all('a', :attrs => {'href'=>/_(git|gatech).txt$/})
        uri.path = git[0]['href']
        http_response = http.get(uri.path)
      end         
      file = File.new('tmp/'+source.filename, "w+")
      file << http_response.body      
      file.close
      file = File.new('/tmp/updates.'+source.filename, "w+")    
      file.close    
      file = File.new('/tmp/removes.'+source.filename, "w+")        
      file.close   
      #lines = http_response.body.split("\n")
      #puts lines[0]
      http_response.body.split("\n").each { | line |
        
        title = line.split("\t")
        
        journal = Journal.find_or_create_by_object_id(title[4])
        if journal.title.blank?
          journal.title = title[1] 
          alt_title = JournalTitle.new(:title=>title[1])
          journal.journal_titles << alt_title
        end
        journal.issn = title[3] if journal.issn.blank?
        journal.eissn = title[7] if journal.eissn.blank?        
        journal.title_source_id = source.id
        journal.normalized_title = title[1].downcase.sub(/^(the|an?)\s/, '') if journal.normalized_title.blank?
        unless journal.normalized_title[0,1].match(/[a-z]/)
          journal.page = '0'
        else 
          journal.page = journal.normalized_title.downcase[0,1]
        end        
        
        journal.save
        unless title[8].blank?
          alt_titles = title[8].split('-')
          for alt_title in alt_titles do
            unless JournalTitle.find_by_title_and_journal_id(alt_title, journal.id)
              alt_title = JournalTitle.new(:title=>alt_title)
              journal.journal_titles << alt_title          
            end
          end
        end  
        unless title[5].blank? and title[6].blank?
          coverage = Coverage.new(:provider=>title[5], :coverage=>title[6])
          journal.coverages << coverage
        end          
        unless title[21].blank?
          subjects = title[21].split(' | ')
          for subject in subjects do
            sub = subject.split(' - ')
            cat = Category.find_or_create_by_category_and_subcategory(sub[0], sub[1])
            journal.categories << cat unless journal.categories.index(cat)
          end
        end      
        journal.save
      }
    }    
  end
  
  task :update_journals => :environment do  
    require 'diff/lcs' 
    require 'rubyful_soup'

    TitleSource.find(:all).each { | source |    
      updates = []
      removes = []    
      uri = URI::parse(source.location)
      http = Net::HTTP.new(uri.host, uri.port)  
      http_response = http.get(uri.path)    
      if source.id == 2
        soup = BeautifulSoup.new(http_response.body)
        git = soup.find_all('a', :attrs => {'href'=>/_(git|gatech).txt$/})
        uri.path = git[0]['href']
        http_response = http.get(uri.path)
      end      
      orig = ''
      orig = IO.readlines("tmp/"+source.filename).join("") if File.exists?('tmp/'+source.filename)
      next if orig == http_response.body
      file = File.new('tmp/'+source.filename, "w+")
      file << http_response.body      
      file.close
      diffs = Diff::LCS.diff(orig.split("\n"), http_response.body.split("\n"))

      diffs.each { | diff |
        diff.each { | d |
          if d.action == "+"
            updates << d.element unless d.element.blank?      
          elsif d.action == "-"
            removes << d.element unless d.element.blank?
          end
        }
      }
      updates.each { | update |    
        title = update.split(/\t/)  
        journal = Journal.find_or_create_by_object_id(title[4])
        if journal.title.blank?
          journal.title = title[1] 
          alt_title = JournalTitle.new(:title=>title[1])
          journal.journal_titles << alt_title
        end
        journal.issn = title[3] if journal.issn.blank?
        journal.eissn = title[7] if journal.eissn.blank?        
        journal.title_source_id = source.id
        journal.normalized_title = title[1].downcase.sub(/^(the|an?)\s/, '') if journal.normalized_title.blank?
        unless journal.normalized_title[0,1].match(/[a-z]/)
          journal.page = '0'
        else 
          journal.page = journal.normalized_title.downcase[0,1]
        end  
        journal.save
        unless title[8].blank?
          alt_titles = title[8].split('-')
          for alt_title in alt_titles do
            unless JournalTitle.find_by_title_and_journal_id(alt_title, journal.id)
              alt_title = JournalTitle.new(:title=>alt_title)
              journal.journal_titles << alt_title          
            end
          end
        end  
        unless title[5].blank? and title[6].blank?
          coverage = Coverage.new(:provider=>title[5], :coverage=>title[6])
          journal.coverages << coverage
        end          
        unless title[21].blank?
          subjects = title[21].split(' | ')
          for subject in subjects do
            sub = subject.split(' - ')
            cat = Category.find_or_create_by_category_and_subcategory(sub[0], sub[1])
            journal.categories << cat unless journal.categories.index(cat)
          end
        end      
        journal.save
      }      
      removes.each { | remove |
        title = remove.split(/\t/)
        journal = Journal.find_by_object_id(title[4])
        journal.coverages.each { | coverage |
          if coverage.provider == title[5] and coverage.coverage == title[6]
            Coverage.delete(coverage.id)
          end
        }
        if journal.coverages.length == 0
          Journal.delete(journal.id)
        end        
      }         
    }       
  
  end
  
  task :sync_journals => :environment do  
    require 'diff/lcs' 
    require 'rubyful_soup'
    titles = ''
    sync = true
    TitleSource.find(:all).each { | source |    
      updates = []
      removes = []    
      uri = URI::parse(source.location)
      http = Net::HTTP.new(uri.host, uri.port)  
      http_response = http.get(uri.path)    
      if source.id == 2
        soup = BeautifulSoup.new(http_response.body)
        git = soup.find_all('a', :attrs => {'href'=>/_(git|gatech).txt$/})
        uri.path = git[0]['href']
        http_response = http.get(uri.path)
      end      
      orig = ''
      orig = IO.readlines("tmp/"+source.filename).join("") if File.exists?('tmp/'+source.filename)
      titles << http_response.body      
      next if orig == http_response.body
      #file = File.new('tmp/'+source.filename, "w+")
      #file << http_response.body      
      #file.close
      diffs = Diff::LCS.diff(orig.split("\n"), http_response.body.split("\n"))
      sync = false if diffs
    }
    return if sync
    journals = {}
    Journals.find(:all).each { | j | journals[j.object_id] = j }
    current_journals = {}
    unmatched_coverages = {}
    new_journals = []
    updated_journals = []
    titles.split('\n').each do | t |
      tabs = title.split("\t")
      title = {
        :object_id => tabs[4],
        :title => tabs[1],
        :issn => tabs[3],
        :eissn => tabs[7],
        :norm_title => tabs[1].downcase.sub(/^(the|an?)\s/, ''),
        :alt_titles => tabs[8],
        :subjects => tabs[21]
      }
                alt_titles = title[8].split('-')
        unless journal.normalized_title[0,1].match(/[a-z]/)
          journal.page = '0'
        else 
          journal.page = journal.normalized_title.downcase[0,1]
        end  



        unless title[8].blank?

          for alt_title in alt_titles do
            unless JournalTitle.find_by_title_and_journal_id(alt_title, journal.id)
              alt_title = JournalTitle.new(:title=>alt_title)
              journal.journal_titles << alt_title          
            end
          end
        end  
        unless title[5].blank? and title[6].blank?
          coverage = Coverage.new(:provider=>title[5], :coverage=>title[6])
          journal.coverages << coverage
        end          
        unless title[21].blank?
          subjects = title[21].split(' | ')
          for subject in subjects do
            sub = subject.split(' - ')
            cat = Category.find_or_create_by_category_and_subcategory(sub[0], sub[1])
            journal.categories << cat unless journal.categories.index(cat)
          end
        end    
    
    end
  end  
end
