# Extracted from dpklib, Ruby library released under same license as Ruby.


class CronTab 
    attr_accessor :min, :hour, :mday, :mon, :wday, :command
  
    WDAY = %w(sun mon tue wed thu fri sat)
    FormatError = Class.new(StandardError)

    def initialize(str)
      super()

      self.min, self.hour, self.mday, self.mon, self.wday =
        CronTab.parse_timedate(str)

      self.command = str.scan( /(?:\S+\s+){5}(.*)/ ).shift
    end

    def ===(rhs)
      judge_date = proc {
        b = true
        b = b && (mday === rhs.mday)
        b = b && (mon === rhs.mon)
        b = b && (wday === rhs.wday)
      }
      judge_hour = proc {
        b = true
        b = b && (min === rhs.min)
        b = b && (hour === rhs.hour)
      }

      case rhs
      when Time
        judge_hour.call && judge_date.call
      when Dpklib::Hour
        judge_hour.call
      when Date
        judge_date.call
      else
        super
      end
    end
    alias include? ===;

    class NextSeeker 
      attr_accessor :scalar, :field, :lower_seeker
      
      def initialize(s, f, l)
        self.scalar = s
        self.field = f
        self.lower_seeker = l
      end
      
      def succ
        if lower_seeker.nil? || lower_seeker.succ then
          self.scalar = field.nextof(scalar)
          scalar
        else
          lower_seeker.recursive_zero
          self.scalar += 1
          succ
        end
      end

      def recursive_zero
        self.scalar = 0
        lower_seeker && lower_seeker.recursive_zero
      end
    end #/NextSeeker

    class YearField
      def nextof(nowyear)
        nowyear
      end
    end #/YearField

    def nexttime(nowtime = Time.now)
      nowmin = nowtime.min + 1

      seeker_min = NextSeeker.new(nowmin, min, nil)
      seeker_hour = NextSeeker.new(nowtime.hour, hour, seeker_min)
      seeker_mday = NextSeeker.new(nowtime.mday, mday, seeker_hour)
      seeker_mon = NextSeeker.new(nowtime.mon, mon, seeker_mday)
      seeker_year = NextSeeker.new(nowtime.year, YearField.new, seeker_mon)
      seeker_year.succ

      Time.local(seeker_year.scalar,
                 seeker_mon.scalar,
                 seeker_mday.scalar,
                 seeker_hour.scalar,
                 seeker_min.scalar, 0)
    end

    def waitsec(nowtime = Time.now)
      nexttime(nowtime).to_i - nowtime.to_i
    end

    def self.parse_timedate(str)
      minute, hour, day_of_month, month, day_of_week =
        str.scan(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/).shift

      day_of_week = day_of_week.downcase.gsub(/#{WDAY.join("|")}/){
        WDAY.index($&)
      }

      [
        parse_field(minute,       0, 59),
        parse_field(hour,         0, 23),
        parse_field(day_of_month, 1, 31),
        parse_field(month,        1, 12),
        parse_field(day_of_week,  0, 6),
      ]
    end

    class Field 
      attr_accessor :range, :every
      
      def initialize(r, e)
        self.range = r
        self.every = e
      end
      
      def ===(rhs)
        b = true
        b = b && ( (rhs - range.first) % every == 0 )
        b = b && ( range === rhs )
      end

      def nextof(now)
        if now < range.first then
          nextof(range.first)
        elsif range.last < now || (range.exclude_end? && range.last <= now) then
          nil
        else
          now + ( (now - range.first) % every )
        end
      end
    end

    class FieldSet 
      attr_accessor :fields
      
      def initialize(f)
        self.fields = f
      end
      
      def ===(rhs)
        b = false
        fields.each { |field|
          b ||= (field === rhs)
        }
        b
      end

      def nextof(now)
        ret = nil
        fields.each { |field|
          field_nextof = field.nextof(now)
          ret = field_nextof if ret.nil? || (field_nextof && field_nextof < ret)
        }
        ret
      end
    end

    def self.parse_field(str, first, last)
      list = str.split(",")
      list.map!{|r|
        r, every = r.split("/")
        every = every ? every.to_i : 1
        f,l = r.split("-")
        range = if f == "*"
                  first..last
                elsif l.nil?
                  f.to_i .. f.to_i
                elsif f.to_i < first
                  raise FormatError.new("out of range (#{f} for #{first})")
                elsif last < l.to_i
                  raise FormatError.new("out of range (#{l} for #{last})")
                else
                  f.to_i .. l.to_i
                end
        Field.new(range, every)
      }
      FieldSet.new(list)
    end

    #alias parse new
    #alias [] new
    
  end #/CronTab


