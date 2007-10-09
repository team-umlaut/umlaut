module OAI
  module XPath

    # get all matching nodes
    def xpath_all(doc, path)
      case parser_type(doc)
      when 'libxml'
        return doc.find(path)
      when 'rexml'
        return REXML::XPath.match(doc, path)
      end
      return []
    end

    # get first matching node
    def xpath_first(doc, path)
      elements = xpath_all(doc, path)
      return elements[0] if elements != nil
      return nil
    end

    # get text for first matching node
    def xpath(doc, path)
      el = xpath_first(doc, path)
      return unless el
      case parser_type(doc)
      when 'libxml'
        return el.content
      when 'rexml'
        return el.text 
      end
      return nil
    end

    # figure out an attribute
    def get_attribute(node, attr_name)
      case node.class.to_s
      when 'REXML::Element'
        return node.attribute(attr_name)
      when 'XML::Node'
        return node.property(attr_name)
      end
      return nil
    end

    private 
   
    # figure out what sort of object we should do xpath on
    def parser_type(x)
      case x.class.to_s
      when 'XML::Document'
        return 'libxml'
      when 'XML::Node'
        return 'libxml'
      when 'XML::Node::Set'
	return 'libxml'
      when 'REXML::Element'
        return 'rexml'
      when 'REXML::Document'
        return 'rexml'
      end
    end
  end
end
