#--
# Copyright (c) 2005 Robert Aman
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'feed_tools/feed'
require 'opensearch_query'
module FeedTools
  # The <tt>FeedTools::OpensearchFeed</tt> class represents a web feed's structure 
  # for an Opensearch query.
  class OpensearchFeed < Feed
    attr_accessor :queries
    def initialize(attrs={})
      #super
      @search_terms = attrs[:search_terms]
      @total_results = attrs[:total_results]
      @start_index = attrs[:start_index]
      @items_per_page = attrs[:count]
      @search_page = nil
      @first_page = nil
      @last_page = nil
      @previous_page = nil
      @next_page = nil
      @queries = {}
      @queries[:request] = FeedTools::OpensearchQuery.new("request", attrs) if @search_terms
    end  
    # Generates xml based on the content of the feed
    def build_xml(feed_type=(self.feed_type or "atom"), feed_version=nil,
        xml_builder=Builder::XmlMarkup.new(
          :indent => 2, :escape_attrs => false))
      xml_builder.instruct! :xml, :version => "1.0",
        :encoding => (self.configurations[:output_encoding] or "utf-8")
      if feed_type.nil?
        feed_type = self.feed_type
      end
      if feed_version.nil?
        feed_version = self.feed_version
      end
      if feed_type == "rss" &&
          (feed_version == nil || feed_version <= 0.0)
        feed_version = 1.0
      elsif feed_type == "atom" &&
          (feed_version == nil || feed_version <= 0.0)
        feed_version = 1.0
      end
      if feed_type == "rss" &&
          (feed_version == 0.9 || feed_version == 1.0 || feed_version == 1.1)
        # RDF-based rss format
        return xml_builder.tag!("rdf:RDF",
            "xmlns" => FEED_TOOLS_NAMESPACES['rss10'],
            "xmlns:content" => FEED_TOOLS_NAMESPACES['content'],
            "xmlns:rdf" => FEED_TOOLS_NAMESPACES['rdf'],
            "xmlns:dc" => FEED_TOOLS_NAMESPACES['dc'],
            "xmlns:syn" => FEED_TOOLS_NAMESPACES['syn'],
            "xmlns:admin" => FEED_TOOLS_NAMESPACES['admin'],
            "xmlns:taxo" => FEED_TOOLS_NAMESPACES['taxo'],
            "xmlns:itunes" => FEED_TOOLS_NAMESPACES['itunes'],
            "xmlns:media" => FEED_TOOLS_NAMESPACES['media'],
            "xmlns:atom" => FEED_TOOLS_NAMESPACES['atom10'],
            "xmlns:opensearch"=>"http://a9.com/-/spec/opensearch/1.1/") do
          channel_attributes = {}
          unless self.link.nil?
            channel_attributes["rdf:about"] =
              FeedTools::HtmlHelper.escape_entities(self.link)
          end
          xml_builder.channel(channel_attributes) do
            unless self.title.blank?
              xml_builder.title(
                FeedTools::HtmlHelper.strip_html_tags(self.title))
            else
              xml_builder.title
            end
            unless self.link.blank?
              xml_builder.link(self.link)
            else
              xml_builder.link
            end
            unless self.search_page.blank?
              xml_builder.tag!("atom:link", 
                {:href=>
                   FeedTools::HtmlHelper.escape_entities(self.search_page),
                 :rel=>"search",
                 :type=>"application/opensearchdescription+xml"                
                }
              )
            end
            self.add_opensearch_tags(xml_builder)
            unless images.blank?
              xml_builder.image("rdf:resource" =>
                FeedTools::HtmlHelper.escape_entities(
                  images.first.url))
            end
            unless description.nil? || description == ""
              xml_builder.description(description)
            else
              xml_builder.description
            end
            unless self.language.blank?
              xml_builder.tag!("dc:language", self.language)
            end
            unless self.rights.blank?
              xml_builder.tag!("dc:rights", self.rights)
            end
            xml_builder.tag!("syn:updatePeriod", "hourly")
            xml_builder.tag!("syn:updateFrequency",
              (self.time_to_live / 1.hour).to_s)
            xml_builder.tag!("syn:updateBase", Time.mktime(1970).iso8601)
            xml_builder.items do
              xml_builder.tag!("rdf:Seq") do
                unless items.nil?
                  for item in items
                    if item.link.nil?
                      raise "Cannot generate an rdf-based feed with a nil " +
                        "item link field."
                    end
                    xml_builder.tag!("rdf:li", "rdf:resource" =>
                      FeedTools::HtmlHelper.escape_entities(item.link))
                  end
                end
              end
            end
            xml_builder.tag!(
              "admin:generatorAgent",
              "rdf:resource" => self.configurations[:generator_href])
            build_xml_hook(feed_type, feed_version, xml_builder)
          end
          unless self.images.blank?
            best_image = nil
            for image in self.images
              if image.link != nil
                best_image = image
                break
              end
            end
            best_image = self.images.first if best_image.nil?
            xml_builder.image("rdf:about" =>
                FeedTools::HtmlHelper.escape_entities(best_image.url)) do
              if !best_image.title.blank?
                xml_builder.title(best_image.title)
              elsif !self.title.blank?
                xml_builder.title(self.title)
              else
                xml_builder.title
              end
              unless best_image.url.blank?
                xml_builder.url(best_image.url)
              end
              if !best_image.link.blank?
                xml_builder.link(best_image.link)
              elsif !self.link.blank?
                xml_builder.link(self.link)
              else
                xml_builder.link
              end
            end
          end
          unless items.nil?
            for item in items
              item.build_xml(feed_type, feed_version, xml_builder)
            end
          end
        end
      elsif feed_type == "rss"
        # normal rss format
        return xml_builder.rss("version" => "2.0",
            "xmlns:content" => FEED_TOOLS_NAMESPACES['content'],
            "xmlns:rdf" => FEED_TOOLS_NAMESPACES['rdf'],
            "xmlns:dc" => FEED_TOOLS_NAMESPACES['dc'],
            "xmlns:taxo" => FEED_TOOLS_NAMESPACES['taxo'],
            "xmlns:trackback" => FEED_TOOLS_NAMESPACES['trackback'],
            "xmlns:itunes" => FEED_TOOLS_NAMESPACES['itunes'],
            "xmlns:media" => FEED_TOOLS_NAMESPACES['media'],
            "xmlns:atom" => FEED_TOOLS_NAMESPACES['atom10'],
            "xmlns:opensearch"=>"http://a9.com/-/spec/opensearch/1.1/") do
          xml_builder.channel do
            unless self.title.blank?
              xml_builder.title(
                FeedTools::HtmlHelper.strip_html_tags(self.title))
            end
            unless self.link.blank?
              xml_builder.link(link)
            end
            unless self.description.blank?
              xml_builder.description(description)
            else
              xml_builder.description
            end
            unless self.author.email.blank?
              xml_builder.managingEditor(self.author.email)
            end
            unless self.publisher.email.blank?
              xml_builder.webMaster(self.publisher.email)
            end
            unless self.published.blank?
              xml_builder.pubDate(self.published.rfc822)
            end
            unless self.updated.blank?
              xml_builder.lastBuildDate(self.updated.rfc822)
            end
            unless self.copyright.blank?
              xml_builder.copyright(self.copyright)
            end
            unless self.search_page.blank?
              xml_builder.tag!("atom:link", 
                {:href=>
                   FeedTools::HtmlHelper.escape_entities(self.search_page),
                 :rel=>"search",
                 :type=>"application/opensearchdescription+xml"                
                }
              )
            end
            self.add_opensearch_tags(xml_builder)            
            xml_builder.ttl((time_to_live / 1.minute).to_s)
            xml_builder.generator(
              self.configurations[:generator_href])
            build_xml_hook(feed_type, feed_version, xml_builder)
            unless items.nil?
              for item in items
                item.build_xml(feed_type, feed_version, xml_builder)
              end
            end
          end
        end
      elsif feed_type == "atom" && feed_version == 0.3
        raise "Atom 0.3 is obsolete."
      elsif feed_type == "atom" && feed_version == 1.0
        namespaces = {}
        # normal atom format
        return xml_builder.feed("xmlns" => FEED_TOOLS_NAMESPACES['atom10'],
            "xmlns:opensearch"=>"http://a9.com/-/spec/opensearch/1.1/",
            "xml:lang" => language) do
          unless title.blank?
            xml_builder.title(title,
                "type" => "html")
          end
          xml_builder.author do
            unless self.author.nil? || self.author.name.nil?
              xml_builder.name(self.author.name)
            else
              xml_builder.name("n/a")
            end
            unless self.author.nil? || self.author.email.nil?
              xml_builder.email(self.author.email)
            end
            unless self.author.nil? || self.author.url.nil?
              xml_builder.uri(self.author.url)
            end
          end
          unless self.href.blank?
            xml_builder.link("href" => self.href,
                "rel" => "self",
                "type" => "application/atom+xml")
          end
          unless self.link.blank?
            xml_builder.link(
              "href" =>
                FeedTools::HtmlHelper.escape_entities(self.link),
              "rel" => "alternate")
          end
          unless self.subtitle.blank?
            xml_builder.subtitle(self.subtitle,
                "type" => "html")
          end
          unless self.next_page.blank?
            xml_builder.link(
              "href" =>
                FeedTools::HtmlHelper.escape_entities(self.next_page),
              "type"=>"application/opensearchdescription+xml",                
              "rel" => "next")          
          end
          unless self.previous_page.blank?
            xml_builder.link(
              "href" =>
                FeedTools::HtmlHelper.escape_entities(self.previous_page),
              "type"=>"application/opensearchdescription+xml",                
              "rel" => "previous")          
          end           
          unless self.first_page.blank?
            xml_builder.link(
              "href" =>
                FeedTools::HtmlHelper.escape_entities(self.first_page),
              "type"=>"application/opensearchdescription+xml",                
              "rel" => "first")          
          end           
          unless self.last_page.blank?
            xml_builder.link(
              "href" =>
                FeedTools::HtmlHelper.escape_entities(self.last_page),
              "type"=>"application/opensearchdescription+xml",                
              "rel" => "last")          
          end       
          unless self.search_page.blank?
            xml_builder.link(
              "href" =>
                FeedTools::HtmlHelper.escape_entities(self.search_page),
              "type"=>"application/opensearchdescription+xml",
              "rel" => "last")          
          end         
          self.add_opensearch_tags(xml_builder)               
          if self.updated != nil
            xml_builder.updated(self.updated.iso8601)
          elsif self.time != nil
            # Not technically correct, but a heck of a lot better
            # than the Time.now fall-back.
            xml_builder.updated(self.time.iso8601)
          else
            xml_builder.updated(Time.now.gmtime.iso8601)
          end
          unless self.rights.blank?
            xml_builder.rights(self.rights)
          end
          xml_builder.generator(self.configurations[:generator_name] +
            " - " + self.configurations[:generator_href])
          if self.id != nil
            unless FeedTools::UriHelper.is_uri? self.id
              if self.link != nil
                xml_builder.id(FeedTools::UriHelper.build_urn_uri(self.link))
              else
                raise "The unique id must be a valid URI."
              end
            else
              xml_builder.id(self.id)
            end
          elsif self.link != nil
            xml_builder.id(FeedTools::UriHelper.build_urn_uri(self.link))
          else
            raise "Cannot build feed, missing feed unique id."
          end
          build_xml_hook(feed_type, feed_version, xml_builder)
          unless items.nil?
            for item in items
              item.build_xml(feed_type, feed_version, xml_builder)
            end
          end
        end
      else
        raise "Unsupported feed format/version."
      end
    end
    def search_page
      return @search_page
    end
    def search_page=(search_page)
      @search_page=search_page
    end
    def first_page
      return @first_page
    end
    def first_page=(first_page)
      @first_page=first_page
    end
    def last_page
      return @last_page
    end
    def last_page=(last_page)    
      @last_page=last_page
    end
    def previous_page
      return @previous_page
    end
    def previous_page=(previous_page)
      @previous_page = previous_page
    end
    def next_page
      return @next_page
    end
    def next_page=(next_page)
      @next_page = next_page
    end

    def add_opensearch_tags(xml)
      xml.opensearch(:totalResults){|tr|tr<<@total_results} if @total_results
      xml.opensearch(:startIndex){|si|si << @start_index} if @start_index         
      xml.opensearch(:itemsPerPage){|ipp|ipp<<@items_per_page} if @items_per_page
      @queries.each { | key, obj |
        obj.build_xml(xml)
      }        
    end
  end
end