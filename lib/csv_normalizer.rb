require 'csv'
require 'time'
require 'tzinfo'

class CSVNormalizer
  class ParseError < StandardError; end

  def initialize(csv_string, on_parse_error:)
    @input_table = CSV.parse(csv_string, headers: true)
    @on_parse_error = on_parse_error
  end

  def normalize
    CSV.generate do |csv|
      csv << @input_table.headers

      @input_table.each do |input_row|
        output_row = CSV::Row.new(@input_table.headers, [])
        begin
          input_row.each do |header, value|
            output_row[header] = normalize_field(header, value)
          end
        rescue ParseError => e
          @on_parse_error.call(e)
        else
          output_row["TotalDuration"] = total_duration(output_row)

          csv << output_row
        end
      end
    end
  end

  private

  def normalize_field(header, value)
    case header
    when "Timestamp"
      Timestamp.new(value).convert(
        TZInfo::Timezone.get('US/Pacific'),
        TZInfo::Timezone.get('US/Eastern')
      )
    when "ZIP"
      value.rjust(5, "0")
    when /Name/
      value.upcase
    when "TotalDuration"
      0
    when /Duration/
      Duration.new(value).to_f
    else
      value
    end
  end

  def total_duration(row)
    durations = row.select do |header, _value|
      header.include?("Duration")
    end.map(&:last).map(&:to_s).map(&:to_r)

    durations.sum.to_f
  end

  class Timestamp
    def initialize(timestamp)
      @time_parts = Date._strptime(timestamp, "%D %r")

      if @time_parts.nil?
        fail ParseError, "unparseable timestamp #{timestamp.dump}"
      end
    end

    def convert(from_tz, to_tz)
      from_time = from_tz.local_time(
        *@time_parts.values_at(:year, :mon, :mday, :hour, :min, :sec)
      )

      to_tz.to_local(from_time.utc).iso8601
    end
  end

  class Duration
    def initialize(duration)
      @hour, @min, @sec, @sec_fraction = Date._parse(duration)
        .values_at(:hour, :min, :sec, :sec_fraction)

      unless @hour && @min && @sec && @sec_fraction
        fail ParseError, "unparseable duration #{duration.dump}"
      end
    end

    def to_f
      ((@hour * 60 * 60) + (@min * 60) + @sec + @sec_fraction).to_f
    end
  end
end
