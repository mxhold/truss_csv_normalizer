require "open3"

RSpec.describe CSVNormalizer do
  let(:exe_filepath) { File.expand_path("../bin/normalize_csv", __dir__) }

  describe "executable" do
    it "normalizes the provided CSV file" do
      input_filepath = File.expand_path("input.csv", __dir__)
      expected_output = File.read(File.expand_path("expected_output.csv", __dir__))

      output = `#{exe_filepath} #{input_filepath}`

      expect(output).to eql(expected_output)
    end

    it "prints a warning and skips lines when unicode replacement makes timestamp invalid" do
      input = <<CSV
Timestamp,Address,ZIP,FullName,FooDuration,BarDuration,TotalDuration,Notes
4/1/11\25511:00:00 AM,"123 4th St, Anywhere, AA",94121,Monkey Alberto,1:23:32.123,1:32:33.123,zzsasdfa,I am the very model of a modern major general
CSV

      stdout_str, stderr_str, _status = Open3.capture3("#{exe_filepath}", stdin_data: input)

      expect(stderr_str).to eql("Skipping line: unparseable timestamp \"4/1/11\\uFFFD11:00:00 AM\"\n")
      expect(stdout_str).to eql("Timestamp,Address,ZIP,FullName,FooDuration,BarDuration,TotalDuration,Notes\n")
    end

    it "prints a warning and skips lines when unicode replacement makes duration invalid" do
      input = <<CSV
Timestamp,Address,ZIP,FullName,FooDuration,BarDuration,TotalDuration,Notes
4/1/11 11:00:00 AM,"123 4th St, Anywhere, AA",94121,Monkey Alberto,1:23:32.\255123,1:32:33.123,zzsasdfa,I am the very model of a modern major general
CSV

      stdout_str, stderr_str, _status = Open3.capture3("#{exe_filepath}", stdin_data: input)

      expect(stderr_str).to eql("Skipping line: unparseable duration \"1:23:32.\\uFFFD123\"\n")
      expect(stdout_str).to eql("Timestamp,Address,ZIP,FullName,FooDuration,BarDuration,TotalDuration,Notes\n")
    end
  end
end
