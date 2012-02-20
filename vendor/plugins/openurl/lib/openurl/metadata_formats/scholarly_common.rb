# encoding: UTF-8

# 
# scholarly_common.rb
# 
# Created on Nov 5, 2007, 3:24:35 PM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 

module OpenURL
  class ScholarlyCommon < ContextObjectEntity
    attr_reader :authors
    def initialize
      super()
      @authors = [OpenURL::Author.new]
      @author_keys = ['aulast','aufirst','auinit','auinit1','auinitm','ausuffix',
        'au', 'aucorp']       
    end
    def method_missing(metadata, value=nil)
      meta = metadata.to_s.sub(/=$/,'')
      raise ArgumentError, "#{meta.to_s} is not a valid #{self.class} metadata field." unless (@author_keys+@metadata_keys).index(meta)
      if metadata.to_s.match(/=$/)
        self.set_metadata(meta, value)
        if @author_keys.index(meta)
          @authors[0].instance_variable_set("@#{meta}", value)
        end
      else
        return self.metadata[meta]
      end
      
    end
    
    def set_metadata(key, val)
      @metadata[key] = val.to_s
      if @author_keys.index(key)
        @authors[0].instance_variable_set("@#{key}", val)
      end      
    end
    
    def genre=(genre)
      raise ArgumentError, "#{genre} is not a valid #{self.class} genre." unless @valid_genres.index(genre)
      self.set_metadata('genre', genre)      
    end
    
    def genre
      return self.metadata["genre"]
    end

    def add_author(author)
      raise ArgumentError, "Argument must be an OpenURL::Author!" unless author.is_a?(OpenURL::Author)
      @authors << author
    end
    
    def remove_author(author)
      idx = author
      idx = @authors.index(author)
      raise ArgumentError unless idx
      @authors.delete_at(idx)      
    end
    
    def serialize_metadata(elem, label)
      meta = {}
      metadata = elem.add_element("ctx:metadata")
      meta["format_container"] = metadata.add_element("#{label}:#{@format}")
      meta["format_container"].add_namespace(label, @xml_ns)
      meta["format_container"].add_attribute("xsi:schemaLocation", "#{@xml_ns} http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:#{@format}")          
      @metadata.each do |k,v|
        next if ['au', 'aucorp', 'auinit', 'auinitm', 'aulast',
          'aufirst', 'auinit1', 'ausuffix'].index(k)
        meta[k] = meta["format_container"].add_element("#{label}:#{k}")
        meta[k].text = v
      end            
      meta["author_container"] = meta["format_container"].add_element("#{label}:authors")
      @authors.each do | author |
        author.xml(meta["author_container"])
      end      
    end

    def import_xml_metadata(node)         
      mbv = REXML::XPath.first(node, "./ctx:metadata-by-val/ctx:metadata/fmt:#{@format}", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx", "fmt"=>@xml_ns})					              
      if mbv
        mbv.to_a.each do |m|
          self.set_metadata(m.name(), m.get_text.value) if m.has_text?                                  
          if m.has_elements?
            m.to_a.each do | md |
              self.set_metadata(md.name(), md.get_text.value) if md.has_text?                              
            end
          end
        end
        auth_num = 0
        REXML::XPath.each(mbv, "fmt:authors/fmt:author | fmt:authors/fmt:au | fmt:authors/fmt:aucorp", {"fmt"=>@xml_ns}) do | author |                    
          empty_node = true
          if author.name == "author"            
            author.elements.each do | auth_elem |            
              next unless @author_keys.index(auth_elem.name) and auth_elem.has_text?
              empty_node = false
              @authors << OpenURL::Author.new unless @authors[auth_num]
              @authors[auth_num].instance_variable_set("@#{auth_elem.name}".to_sym, auth_elem.get_text.value)
              self.set_metadata(auth_elem.name, auth_elem.get_text.value) if auth_num == 0
            end
          elsif author.name.match(/^au$|^aucorp$/)
            next unless author.has_text? 
            empty_node = false
            @authors << OpenURL::Author.new unless @authors[auth_num]
            # This next line is causing an exception, replaced it with following line modeling from above clause. Don't entirely understand it. 
            # @authors[auth_num][author.name] = author.get_text.value
            @authors[auth_num].instance_variable_set("@#{author.name}".to_sym, author.get_text.value)
            self.set_metadata(author.name, author.get_text.value) if auth_num == 0            
          end
          auth_num += 1 unless empty_node
        end        
      end					
    end     
  end
  
  class Author
    attr_accessor :aulast, :aufirst, :auinit, :auinit1, :auinitm, :ausuffix,
      :au, :aucorp
    def initialize      
    end
    
    def xml(elem)      
      if @au        
        au = elem.add_element("#{elem.prefix}:au") 
        au.text = @au
      end
      if @aucorp
        aucorp = elem.add_element("#{elem.prefix}:aucorp") 
        aucorp.text = @aucorp
      end
      if @aulast || @aufirst || @auinit || @auinit1 || @auinitm || @ausuffix
        author = elem.add_element("#{elem.prefix}:author")
        if @aulast
          aulast = author.add_element("#{elem.prefix}:aulast")
          aulast.text = @aulast
        end
        if @aufirst
          aufirst = author.add_element("#{elem.prefix}:aufirst")
          aufirst.text = @aufirst
        end        
        if @auinit
          auinit = author.add_element("#{elem.prefix}:auinit")
          auinit.text = @auinit
        end        
        if @auinit1
          auinit1 = author.add_element("#{elem.prefix}:auinit1")
          auinit1.text = @auinit1
        end        
        if @auinitm
          auinitm = author.add_element("#{elem.prefix}:auinitm")
          auinitm.text = @auinitm
        end        
        if @ausuffix
          ausuff = author.add_element("#{elem.prefix}:ausuffix")
          ausuff.text = @ausuffix
        end        
      end
    end
    
    def empty?
      self.instance_variables.each do | ivar |
        return false if self.instance_variable_get(ivar)
      end
      return true
    end    
  end  
  
  class Inventor
    attr_accessor :invlast, :invfirst, :inv
    def initialize      
    end
    
    def xml(elem)      
      if @inv        
        inv = elem.add_element("#{elem.prefix}:inv") 
        inv.text = @inv
      end
      if @invlast || @invfirst
        inventor = elem.add_element("#{elem.prefix}:inventor")
        if @invlast
          invlast = inventor.add_element("#{elem.prefix}:invlast")
          invlast.text = @invlast
        end
        if @invfirst
          invfirst = inventor.add_element("#{elem.prefix}:invfirst")
          invfirst.text = @invfirst
        end             
      end
    end
    
    def empty?
      self.instance_variables.each do | ivar |
        return false if self.instance_variable_get(ivar)
      end
      return true
    end
  end   
end
