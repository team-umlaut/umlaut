#!/usr/local/bin/ruby -rubygems
require 'camping'
require 'camping/session'
require 'oai/provider'

# Extremely simple demo Camping application to illustrate OAI Provider integration
# with Camping. 
#
# William Groppe 2/1/2007
#

Camping.goes :DublinCore

module DublinCore
  include Camping::Session
  
  FIELDS = ['title', 'creator', 'subject', 'description', 
    'publisher', 'contributor', 'date', 'type', 'format', 
    'identifier', 'source', 'language', 'relation', 'coverage', 'rights']

  def DublinCore.create
    Camping::Models::Session.create_schema
    DublinCore::Models.create_schema :assume =>
      (DublinCore::Models::Obj.table_exists? ? 1.0 : 0.0)
  end
  
end

module DublinCore::Models
  Base.logger = Logger.new("dublin_core.log")
  Base.inheritance_column = 'field_type'
  Base.default_timezone = :utc

  class Obj < Base # since Object is reserved
    has_and_belongs_to_many :fields, :join_table => 'dublincore_field_links', 
      :foreign_key => 'obj_id', :association_foreign_key => 'field_id'
    DublinCore::FIELDS.each do |field|
      class_eval(%{
        def #{field.pluralize}
          fields.select do |f|
            f if f.field_type == "DC#{field.capitalize}"
          end
        end
      });
    end
  end
  
  class Field < Base
    has_and_belongs_to_many :objs, :join_table => 'dublincore_field_links', 
      :foreign_key => 'field_id', :association_foreign_key => 'obj_id'
    validates_presence_of :field_type, :message => "can't be blank"
    
    # Support sorting by value
    def <=>(other)
      self.to_s <=> other.to_s
    end
      
    def to_s
      value
    end
  end
  
  DublinCore::FIELDS.each do |field|
    module_eval(%{
      class DC#{field.capitalize} < Field; end
    })
  end
  
  # OAI Provider configuration
  class CampingProvider < OAI::Provider::Base
    repository_name 'Camping Test OAI Repository'
    source_model ActiveRecordWrapper.new(Obj)
  end
  
  class CreateTheBasics < V 1.0
    def self.up
      create_table :dublincore_objs, :force => true do |t|
        t.column  :source, :string
        t.column  :created_at,  :datetime
        t.column  :updated_at,  :datetime
      end 
      
      create_table :dublincore_field_links, :id => false, :force => true do |t|
        t.column  :obj_id, :integer, :null => false
        t.column  :field_id,  :integer, :null => false
      end
      
      create_table :dublincore_fields, :force => true do |t|
        t.column  :field_type,  :string,  :limit => 30, :null => false
        t.column  :value,       :text,  :null => false
      end
      
      add_index :dublincore_fields, [:field_type, :value], :uniq => true
      add_index :dublincore_field_links, :field_id
      add_index :dublincore_field_links, [:obj_id, :field_id]
    end
    
    def self.down
      drop_table :dublincore_objs
      drop_table :dublincore_field_links
      drop_table :dublincore_fields
    end
  end
  
end

module DublinCore::Controllers
  
  # Now setup a URL('/oai' by default) to handle OAI requests
  class Oai
    def get
      @headers['Content-Type'] = 'text/xml'
      provider = Models::CampingProvider.new
      provider.process_request(@input.merge(:url => "http:"+URL(Oai).to_s))
    end
  end
  
  class Index < R '/', '/browse/(\w+)', '/browse/(\w+)/page/(\d+)'
    def get(field = nil, page = 1)
      @field = field
      @page = page.to_i
      @browse = {}
      if !@field 
        FIELDS.each do |field|
          @browse[field] = Field.count(
            :conditions => ["field_type = ?", "DC#{field.capitalize}"])
        end
        @home = true
        @count = @browse.keys.size
      else
        @count = Field.count(:conditions => ["field_type = ?", "DC#{@field.capitalize}"])
        fields = Field.find(:all, 
          :conditions => ["field_type = ?", "DC#{@field.capitalize}"],
          :order => "value asc", :limit => DublinCore::LIMIT, 
          :offset => (@page - 1) * DublinCore::LIMIT)
          
        fields.each do |field|
          @browse[field] = field.objs.size
        end
      end
      render :browse
    end
  end
  
  class Search < R '/search', '/search/page/(\d+)'
    
    def get(page = 1)
      @page = page.to_i
      if input.terms
        @state.terms = input.terms if input.terms
      
        start = Time.now
        ids = search(input.terms, @page - 1)
        finish = Time.now
        @search_time = (finish - start)
        @objs = Obj.find(ids)
      else
        @count = 0
        @objs = []
      end
      
      render :search
    end
    
  end
  
  class LinkedTo < R '/linked/(\d+)', '/linked/(\d+)/page/(\d+)'
    def get(field, page = 1)
      @page = page.to_i
      @field = field
      @count = Field.find(field).objs.size
      @objs = Field.find(field).objs.find(:all, 
        :limit => DublinCore::LIMIT, 
        :offset => (@page - 1) * DublinCore::LIMIT)
      render :records
    end
  end
  
  class Add
    def get
      @obj = Obj.create
      render :edit
    end
  end
  
  class View < R '/view/(\d+)'
    def get obj_id
      obj = Obj.find(obj_id)
      # Get rid of completely empty records
      obj.destroy if obj.fields.empty?

      @count = 1
      @objs = [obj]
      if Obj.exists?(obj.id)
        render :records if Obj.exists?(obj.id)
      else
        redirect Index
      end
    end
  end
  
  class Edit < R '/edit', '/edit/(\d+)'
    def get obj_id
      @obj = Obj.find obj_id
      render :edit
    end
    
    def post
      case input.action
      when 'Save'
        @obj = Obj.find input.obj_id
        @obj.fields.clear
        input.keys.each do |key|
          next unless key =~ /^DublinCore::Models::\w+/
          next unless input[key] && !input[key].empty?
          input[key].to_a.each do |value|
            @obj.fields << key.constantize.find_or_create_by_value(value)
          end
        end
        redirect View, @obj
      when 'Discard'
        @obj = Obj.find input.obj_id
        
        # Get rid of completely empty records
        @obj.destroy if @obj.fields.empty?
        
        if Obj.exists?(@obj.id)
          redirect View, @obj
        else
          redirect Index
        end
      when 'Delete'
        Obj.find(input.obj_id).destroy
        render :delete_success
      end
    end
  end
  
  class DataAdd < R '/data/add'
    def post
      if input.field_value && !input.field_value.empty?
        model = "DublinCore::Models::#{input.field_type}".constantize
        obj = Obj.find(input.obj_id)
        obj.fields << model.find_or_create_by_value(input.field_value)
      end
      redirect Edit, input.obj_id
    end
  end
  
  class Style < R '/styles.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = %{
        body { width: 750px; margin: 0; margin-left: auto; margin-right: auto; padding: 0;
          color: black; background-color: white; }
        a { color: #CC6600; text-decoration: none; }
        a:visited { color: #CC6600; text-decoration: none;}
        a:hover { text-decoration: underline; }
        a.stealthy { color: black; }
        a.stealthy:visited { color: black; }
        .header { text-align: right; padding-right: .5em; }
        div.search { text-align: right; position: relative; top: -1em; }
        div.search form input { margin-right: .25em; }
        .small { font-size: 70%; }
        .tiny { font-size: 60%; }
        .totals { font-size: 60%; margin-left: .25em; vertical-align: super; }
        .field_labels { font-size: 60%; margin-left: 1em; vertical-align: super; }
        h2 {color: #CC6600; padding: 0; margin-bottom: .15em; font-size: 160%;}
        h3.header { padding:0; margin:0; position: relative; top: -2.8em; 
          padding-bottom: .25em; padding-right: 5em; font-size: 80%; }
        h1.header a { color: #FF9900; text-decoration: none;
          font: bold 250% "Trebuchet MS",Trebuchet,Georgia, Serif;
          letter-spacing:-4px; }

        div.pagination { text-align: center; }
        ul.pages { list-style: none; padding: 0; display: inline;}
        ul.pages li { display: inline; }
        form.controls { text-align: right; }
        ul.undecorated { list-style: none; padding-left: 1em; margin-bottom: 5em;}
        .content { padding-left: 2em; padding-right: 2em; }
        table { padding: 0; background-color: #CCEECC; font-size: 75%;
          width: 100%; border: 1px solid black; margin: 1em; margin-left: auto; margin-right: auto; }
        table.obj tr.controls { text-align: right; font-size: 100%; background-color: #AACCAA; }
        table.obj td.label { width: 7em; padding-left: .25em; border-right: 1px solid black; }
        table.obj td.value input { width: 80%; margin: .35em; }
        input.button { width: 5em; margin-left: .5em; }
        table.add tr.controls td { padding: .5em; font-size: 100%; background-color: #AACCAA; }
        table.add td { width: 10%; }
        table.add td.value { width: 80%; }
        table.add td.value input { width: 100%; margin: .35em; }
      }
    end
  end
end

module DublinCore::Helpers
  
  def paginate(klass, term = nil)
    @total_pages = count/DublinCore::LIMIT + 1
    div.pagination do
      p "#{@page} of #{@total_pages} pages"
      ul.pages do
        li { link_if("<<", klass, term, 1) }
        li { link_if("<", klass, term, @page - 1) }
        page_window.each do |page|
          li { link_if("#{page}", klass, term, page) }
        end
        li { link_if(">", klass, term, @page + 1) }
        li { link_if(">>", klass, term, @total_pages) }
      end
    end
  end
  
  private
  
  def link_if(string, klass, term, page)
    return "#{string} " if (@page == page || 1 > page || page > @total_pages)
    a(string, :href => term.nil? ? R(klass, page) : R(klass, term, page)) << " "
  end
  
  def page_window
    return 1..@total_pages if @total_pages < 9
    size = @total_pages > 9 ? 9 : @total_pages
    start = @page - size/2 > 0 ? @page - size/2 : 1
    start = @total_pages - size if start+size > @total_pages
    start..start+size
  end
  
end

module DublinCore::Views
  
  def layout
    html do
      head do
        title "Dublin Core - Simple Asset Cataloger"
          link :rel => 'stylesheet', :type => 'text/css',
               :href => '/styles.css', :media => 'screen'
      end
      body do
        h1.header { a 'Nugget Explorer', :href => R(Index) }
        h3.header { "exposing ugly metadata" }
        div.search do
          form({:method => 'get', :action => R(Search)}) do
            input :name => 'terms', :type => 'text'
            input.button :type => :submit, :value => 'Search'
          end
        end
        a("Home", :href => R(Index)) unless @home
        div.content do
          self << yield
        end
      end
    end
  end
  
  def browse
    if @browse.empty?
      p 'No objects found, try adding one.'
    else
      h3 "Browsing" << (" '#{@field}'" if @field).to_s
      ul.undecorated do
        @browse.keys.sort.each do |key|
          li { _key_value(key, @browse[key]) }
        end
      end
      paginate(Index, @field) if @count > DublinCore::LIMIT
    end
  end
  
  def delete_success
    p "Delete was successful"
  end
    
  def search
    p.results { span "#{count} results for '#{@state.terms}'"; span.tiny "(#{@search_time} secs)" }
    ul.undecorated do
      @result.keys.sort.each do |record|
        li do
          a(record.value, :href => R(LinkedTo, record.id)) 
          span.totals "(#{@result[record]})"
          span.field_labels "#{record.field_type.sub(/^DC/, '').downcase} "
        end
      end
    end
    paginate(Search) if @count > DublinCore::LIMIT
  end
  
  def edit
    h3 "Editing Record"
    p "To remove a field entry, just remove it's content."
    _form(@obj, :action => R(Edit, @obj))
  end
  
  def records
    @objs.each { |obj| _obj(obj) }
    paginate(LinkedTo, @field) if @count > DublinCore::LIMIT
  end
        
  def _obj(obj, edit = false)
    table.obj :cellspacing => 0 do
      _edit_controls(obj, edit)
      DublinCore::FIELDS.each do |field|
        obj.send(field.pluralize.intern).each_with_index do |value, index|
          tr do
            td.label { 0 == index ? "#{field}(s)" : "&nbsp;" }
            if edit
              td.value do
                input :name => value.class, 
                  :type => 'text', 
                  :value => value.to_s
              end
            else
              td.value { a.stealthy(value, :href => R(LinkedTo, value.id)) }
            end
          end
        end
      end
    end
  end
  
  def _form(obj, action)
    form.controls(:method => 'post', :action => R(Edit)) do
      input :type => 'hidden', :name => 'obj_id', :value => obj.id
      _obj(obj, true)
      input.button :type => :submit, :name => 'action', :value => 'Save'
      input.button :type => :submit, :name => 'action', :value => 'Discard'
    end
    form(:method => 'post', :action => R(DataAdd)) do
      input :type => 'hidden', :name => 'obj_id', :value => obj.id
      table.add :cellspacing => 0 do
        tr.controls do
          td(:colspan => 3) { "Add an entry.  (All changes above will be lost, so save them first)" }
        end
        tr do
          td do
            select(:name => 'field_type') do
              DublinCore::FIELDS.each do |field|
                option field, :value => "DC#{field.capitalize}"
              end
            end
          end
          td.value { input :name => 'field_value', :type => 'text' }
          td { input.button :type => 'submit', :value => 'Add' }
        end
      end
    end
  end
  
  def _edit_controls(obj, edit)
    tr.controls do
      td :colspan => 2 do
        edit ? input(:type => 'submit', :name => 'action', :value => 'Delete') :
        a('edit', :href => R(Edit, obj))
      end
    end
  end
    
  
  def _key_value(key, value)
    if value > 0
      if key.kind_of?(DublinCore::Models::Field)
        a(key, :href => R(LinkedTo, key.id))
      else
        a(key.to_s, :href => R(Index, key))
      end
      span.totals "(#{value})"
    else
      span key
      span.totals "(#{value})"
    end
  end
          
end
