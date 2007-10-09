class Record
  attr_accessor :id, :titles, :creator, :tags, :sets, :updated_at, :deleted
  
  def initialize(id, 
      titles = 'title', 
      creator = 'creator', 
      tags = 'tag', 
      sets = nil, 
      deleted = false,
      updated_at = Time.new.utc)
      
    @id = id;
    @titles = titles
    @creator = creator
    @tags = tags
    @sets = sets
    @deleted = deleted
    @updated_at = updated_at
  end
  
  # Override Object.id
  def id
    @id
  end
  
  def in_set(spec)
    if @sets.respond_to?(:each)
      @sets.each { |set| return true if set.spec == spec }
    else
      return true if @sets.spec == spec
    end
    false
  end
  
end

class TestModel < OAI::Provider::Model
  include OAI::Provider
  
  def initialize(limit = nil)
    super(limit)
    @records = []
    @sets = []
    @earliest = Time.now
  end
  
  def earliest
    (@records.min {|a,b| a.updated_at <=> b.updated_at }).updated_at
  end
  
  def latest
    @records.max {|a,b| a.updated_at <=> b.updated_at }.updated_at
  end

  def sets
    @sets
  end
  
  def find(selector, opts={})
    return nil unless selector

    case selector
    when :all
      if opts[:resumption_token]
        raise OAI::ResumptionTokenException.new unless @limit
        begin
          token = ResumptionToken.parse(opts[:resumption_token])

          if token.last < @groups.size - 1
            PartialResult.new(@groups[token.last], token.next(token.last + 1))
          else
            @groups[token.last]
          end
        rescue
          raise OAI::ResumptionTokenException.new
        end
      else
        records = @records.select do |rec|
          ((opts[:set].nil? || rec.in_set(opts[:set])) && 
          (opts[:from].nil? || rec.updated_at >= opts[:from]) &&
          (opts[:until].nil? || rec.updated_at <= opts[:until]))
        end

        if @limit && records.size > @limit
          @groups = generate_chunks(records, @limit)
          return PartialResult.new(@groups[0], 
            ResumptionToken.new(opts.merge({:last => 1})))
        end
        return records
      end
    else
      begin
        @records.each do |record|
          return record if record.id.to_s == selector
        end
      rescue
      end
      nil
    end
  end
  
  def generate_chunks(records, limit)
    groups = []
    records.each_slice(limit) do |group|
      groups << group
    end
    groups
  end
      
  def generate_records(number, timestamp = Time.now, sets = [], deleted = false)
    @earliest = timestamp.dup if @earliest.nil? || timestamp < @earliest
    
    # Add any sets we don't already have
    sets = [sets] unless sets.respond_to?(:each)
    sets.each do |set|
      @sets << set unless @sets.include?(set)
    end 
    
    # Generate some records
    number.times do |id|
      rec = Record.new(@records.size, "title_#{id}", "creator_#{id}", "tag_#{id}")
      rec.updated_at = timestamp.utc
      rec.sets = sets
      rec.deleted = deleted
      @records << rec
    end
  end
    
end

class SimpleModel < TestModel
  
  def initialize
    super
    # Create a couple of sets
    set_one = OAI::Set.new()
    set_one.name = "Test Set One"
    set_one.spec = "A"
    set_one.description = "This is test set one."

    set_two = OAI::Set.new()
    set_two.name = "Test Set Two"
    set_two.spec = "A:B"
    set_two.description = "This is test set two."

    generate_records(5, Chronic.parse("oct 5 2002"), set_one)
    generate_records(1, Chronic.parse("nov 5 2002"), [set_two], true)
    generate_records(4, Chronic.parse("nov 5 2002"), [set_two])
  end

end

class BigModel < TestModel
  
  def initialize(limit = nil)
    super(limit)
    generate_records(100, Chronic.parse("October 2 2000"))
    generate_records(100, Chronic.parse("November 2 2000"))
    generate_records(100, Chronic.parse("December 2 2000"))
    generate_records(100, Chronic.parse("January 2 2001"))
    generate_records(100, Chronic.parse("February 2 2001"))
  end
  
end

class MappedModel < TestModel

  def initialize
    super
    set_one = OAI::Set.new()
    set_one.name = "Test Set One"
    set_one.spec = "A"
    set_one.description = "This is test set one."

    generate_records(5, Chronic.parse("dec 1 2006"), set_one)
  end
  
  def map_oai_dc
    {:title => :creator, :creator => :titles, :subject => :tags}
  end

end

class ComplexModel < TestModel
  
  def initialize(limit = nil)
    super(limit)
    # Create a couple of sets
    set_one = OAI::Set.new
    set_one.name = "Set One"
    set_one.spec = "One"
    set_one.description = "This is test set one."

    set_two = OAI::Set.new
    set_two.name = "Set Two"
    set_two.spec = "Two"
    set_two.description = "This is test set two."

    set_three = OAI::Set.new
    set_three.name = "Set Three"
    set_three.spec = "Three"
    set_three.description = "This is test set three."

    set_four = OAI::Set.new
    set_four.name = "Set Four"
    set_four.spec = "Four"
    set_four.description = "This is test set four."

    set_one_two = OAI::Set.new
    set_one_two.name = "Set One and Two"
    set_one_two.spec = "One:Two"
    set_one_two.description = "This is combination set of One and Two."

    set_three_four = OAI::Set.new
    set_three_four.name = "Set Three and Four"
    set_three_four.spec = "Three:Four"
    set_three_four.description = "This is combination set of Three and Four."

    generate_records(250, Chronic.parse("May 2 1998"), [set_one, set_one_two])
    generate_records(50, Chronic.parse("June 2 1998"), [set_one, set_one_two], true)
    generate_records(50, Chronic.parse("October 10 1998"), [set_three, set_three_four], true)
    generate_records(250, Chronic.parse("July 2 2002"), [set_two, set_one_two])
    
    generate_records(250, Chronic.parse("September 15 2004"), [set_three, set_three_four])
    generate_records(50, Chronic.parse("October 10 2004"), [set_three, set_three_four], true)
    generate_records(250, Chronic.parse("December 25 2005"), [set_four, set_three_four])
  end
  
end

