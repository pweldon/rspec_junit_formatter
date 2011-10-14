require 'time'

# Dumps rspec results as a JUnit XML file.
# Based on XML schema: http://windyroad.org/dl/Open%20Source/JUnit.xsd
class RSpec::Core::Formatters::JUnitFormatter < RSpec::Core::Formatters::BaseFormatter
  def xml
    @xml ||= Builder::XmlMarkup.new :target => output, :indent => 2
  end

  def start example_count
    @start = Time.now
    super
  end

  def dump_summary duration, example_count, failure_count, pending_count
    super

    examples_by_path = examples.group_by { |example| example.file_path }
    common_prefix_length = examples_by_path.keys.map { |path| path.split('/').size }.min - 2
    common_prefix_length = 0 if common_prefix_length < 0

    xml.instruct!
    xml.testsuites do
      examples_by_path.each do |path, examples|
        name = path.gsub(/.rb$/,'').split('/').drop(common_prefix_length).join('.')
        xml.testsuite(:tests => examples.size,
                      :failures => examples.count { |e| e.execution_result[:status] != 'passed' },
                      :package => name[0..-2],
                      :name => name.last,
                      :errors => 0,
                      :time => '%.6f' % duration,
                      :timestamp => @start.iso8601) do
          xml.properties
          examples.each do |example|
            send :"dump_summary_example_#{example.execution_result[:status]}", example
          end
        end
      end
    end
  end

  def xml_example example, &block
    xml.testcase :classname => example.example_group.ancestors.reverse.map { |eg| eg.description }.join('.'), :name => example.description, :time => '%.6f' % example.execution_result[:run_time], &block
  end

  def dump_summary_example_passed example
    xml_example example
  end

  def dump_summary_example_pending example
    xml_example example do
      xml.skipped
    end
  end

  def dump_summary_example_failed example
    exception = example.execution_result[:exception]
    backtrace = format_backtrace exception.backtrace, example

    xml_example example do
      xml.failure :message => exception.to_s, :type => exception.class.name do
        xml.cdata! "#{exception.message}\n#{backtrace.join "\n"}"
      end
    end
  end
end
