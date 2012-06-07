#!/usr/bin/ruby
#
# ocunit2junit.rb was written by Christian Hedin <christian.hedin@jayway.com>
# Version: 0.1 - 30/01 2010
# Usage:
# xcodebuild -yoursettings | ocunit2junit.rb
# All output is just passed through to stdout so you don't miss a thing!
# JUnit style XML-report are put in the folder specified below.
#
# Known problems:
# * "Errors" are not caught, only "warnings".
# * It's not possible to click links to failed test in Hudson
# * It's not possible to browse the source code in Hudson
#
# Acknowledgement:
# Big thanks to Steen Lehmann for prettifying this script.
################################################################
# Edit these variables to match your system
#
#
# Where to put the XML-files from your unit tests
TEST_REPORTS_FOLDER = "test-reports"
#
#
# Don't edit below this line
################################################################

#########
# Brian Coyner Notes
# - Added support for multiple lines in an error message
#
# - Added support for "parameterized" tests (i.e. execute same test method with different input data)
#   - See http://briancoyner.github.com/blog/2011/09/12/ocunit-parameterized-test-case/
#
# - Renamed variables to match the actual intended use (viz. test_case -> test_method_name)
#
# - Added support to recursively create the output directory (mkdir_p)
#########


require 'time'
require 'fileutils'
require 'socket'

class ReportParser

  attr_reader :exit_code

  def initialize(piped_input)
    @piped_input = piped_input
    @exit_code = 0

    FileUtils.rm_rf(TEST_REPORTS_FOLDER)

    # recursively create the output folders
    FileUtils.mkdir_p(TEST_REPORTS_FOLDER)
    parse_input
  end

  private

  def parse_input
    current_test_that_failed = nil

    @piped_input.each do |piped_row|
      puts piped_row
      case piped_row

        when /Test Suite '(\S+)'.*started at\s+(.*)/
          t = Time.parse($2.to_s)
          handle_start_test_suite(t)

        when /Test Suite '(\S+)'.*finished at\s+(.*)./
          t = Time.parse($2.to_s)
          handle_end_test_suite($1, t)

        when /Test Case '-\[\S+\s+(\S+)\]' started./
          generate_test_case_method_name($1)

        when /Test Case '-\[\S+\s+(\S+)\]' passed \((.*) seconds\)/
          test_method = get_test_case_method_name($1)
          test_method_duration = $2.to_f
          handle_test_passed(test_method, test_method_duration)

        when /(.*): error: -\[(\S+) (\S+)\] : (.*)/
          error_location = $1
          test_suite = $2
          test_method = get_test_case_method_name($3)

          error_message = $4
          handle_test_error(test_suite, test_method, error_message, error_location)
          current_test_that_failed = test_method

        when /Test Case '-\[\S+ (\S+)\]' failed \((\S+) seconds\)/
          test_method = get_test_case_method_name($1)
          test_method_duration = $2.to_f
          handle_test_failed(test_method, test_method_duration)

          current_test_that_failed = nil
        when /failed with exit code (\d+)/
          @exit_code = $1.to_i

        when /BUILD FAILED/
          @exit_code = -1
        else
          if current_test_that_failed
            append_test_error(current_test_that_failed, piped_row)
          end

        # ignore the line
      end
    end
  end

  def generate_test_case_method_name(test_method_name)
    count = @test_method_count[test_method_name].to_i
    count += 1
    @test_method_count[test_method_name] = count

    if count == 1
      test_method_name
    else
      test_method_name + "[" + count.to_s + "]"
    end
  end

  def get_test_case_method_name(test_method_name)
    count = @test_method_count[test_method_name].to_i
    if count == 1
      test_method_name
    else
      test_method_name + "[" + count.to_s + "]"
    end
  end

  def handle_start_test_suite(start_time)
    @total_failed_test_methods = 0
    @total_passed_test_methods = 0
    @test_method_count = Hash.new
    @tests_results = Hash.new # test_method_name -> duration
    @errors = Hash.new # test_method_name -> error_msg
    @ended_current_test_suite = false
    @cur_start_time = start_time
  end

  def handle_end_test_suite(test_case_name, end_time)
    unless @ended_current_test_suite
      current_file = File.open("#{TEST_REPORTS_FOLDER}/TEST-#{test_case_name}.xml", 'w')
      host_name = string_to_xml Socket.gethostname
      test_case_name = string_to_xml test_case_name
      test_duration = (end_time - @cur_start_time).to_s
      total_tests = @total_failed_test_methods + @total_passed_test_methods
      suite_info = '<testsuite errors="0" failures="'+@total_failed_test_methods.to_s+'" hostname="'+host_name+'" name="'+test_case_name+'" tests="'+total_tests.to_s+'" time="'+test_duration.to_s+'" timestamp="'+end_time.to_s+'">'
      current_file << "<?xml version='1.0' encoding='UTF-8' ?>\n"
      current_file << suite_info

      @tests_results.each do |t|
        test_method_name = string_to_xml t[0]
        duration = @tests_results[test_method_name]
        current_file << "<testcase classname='#{test_case_name}' name='#{test_method_name}' time='#{duration.to_s}'"
        if @errors[test_method_name].nil?
          current_file << " />\n"
        else
          # uh oh we got a failure
          puts "tests_errors[0]"
          puts @errors[test_method_name][0]
          puts "tests_errors[1]"
          puts @errors[test_method_name][1]

          message = string_to_xml @errors[test_method_name][0].to_s
          location = string_to_xml @errors[test_method_name][1].to_s
          current_file << ">\n"
          current_file << "<failure message='#{message}' type='Failure'>#{location}</failure>\n"
          current_file << "</testcase>\n"
        end
      end
      current_file << "</testsuite>\n"
      current_file.close
      @ended_current_test_suite = true
    end
  end

  def string_to_xml(s)
    # Added support for new line characters
    s.gsub(/&/, '&amp;').gsub(/'/, '&quot;').gsub(/</, '&lt;').gsub(/\n/,'&#xa;')
  end

  def handle_test_passed(test_method_name, test_method_duration)
    @total_passed_test_methods += 1
    @tests_results[test_method_name] = test_method_duration
  end

  def handle_test_error(test_suite, test_method_name, error_message, error_location)
    @errors[test_method_name] = [error_message, error_location]
  end

  def append_test_error(test_method_name, message)
    values = @errors[test_method_name]
    values[0] = values[0] + message
  end

  def handle_test_failed(test_method_name, test_method_duration)
    @total_failed_test_methods +=1
    @tests_results[test_method_name] = test_method_duration
  end

end

#Main
#piped_input = File.open("tests_fail.txt") # for debugging this script
piped_input = ARGF.read

report = ReportParser.new(piped_input)

exit report.exit_code
