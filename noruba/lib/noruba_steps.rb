require 'securerandom'

require 'cucumber/rspec/doubles'
require 'cucumber/cli/main'

def write_file(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.open(path, 'w') { |file| file.write(content) }
end

def clean_output(output)
  output.split("\n").map do |line|
    next if line.include?("lib/noruba_steps.rb")
    line
      .gsub(/\e\[([;\d]+)?m/, '')                  # Drop trailing whitespaces
      .gsub(/^.*cucumber_process\.rb.*$\n/, '')
      .gsub(/^\d+m\d+\.\d+s$/, '0m0.012s')         # Make duration predictable
      .gsub(/Coverage report generated .+$\n/, '') # Remove SimpleCov message
      .sub(/\s*$/, '')
  end.compact.join("\n")
end


def output_starts_with(source, expected)
  expect(clean_output(source)).to start_with(clean_output(expected))
end

def output_equals(source, expected)
  expect(clean_output(source)).to eq(clean_output(expected))
end

def output_include(source, expected)
  expect(clean_output(source)).to include(clean_output(expected))
end

def output_include_not(source, expected)
  expect(clean_output(source)).not_to include(clean_output(expected))
end

class MockKernel
  attr_reader :exit_status

  def exit(status)
    @exit_status  = status
  end
end

class CucumberCommand
  def initialize()
    @stdout = StringIO.new
    @stderr = StringIO.new
    @kernel = MockKernel.new
  end

  def execute(args)
    Cucumber::Cli::Main.new(
      make_arg_list(args),
      nil,
      @stdout,
      @stderr,
      @kernel
    ).execute!
  end

  def stderr
    @stderr.string
  end

  def stdout
    @stdout.string
  end

  def all_output
    [stdout, stderr].reject(&:empty?).join("\n")
  end

  def exit_status
    @kernel.exit_status
  end

  private

  def make_arg_list(args)
    index = -1
    args.split(/'|"/).map do |chunk|
      index += 1
      index % 2 == 0 ? chunk.split(' ') : chunk
    end.flatten
  end
end

Before do
  @original_cwd = Dir.pwd
  @tmp_working_directory = File.join('tmp', "noruba-#{SecureRandom.uuid}")

  FileUtils.rm_rf(@tmp_working_directory)
  FileUtils.mkdir_p(@tmp_working_directory)

  Dir.chdir(@tmp_working_directory)

  @cucumber = CucumberCommand.new()
end

After do
  Dir.chdir(@original_cwd)
end

Given('a directory named {string}') do |path|
  FileUtils.mkdir_p(File.dirname(path))
end


Given('a directory without standard Cucumber project directory structure') do
end

Given('the standard step definitions') do
  write_file 'features/step_definitions/steps.rb',
             <<-STEPS
  Given(/^this step passes$/)          { }
  Given(/^this step raises an error$/) { raise 'error' }
  Given(/^this step is pending$/)      { pending }
  Given(/^this step fails$/)           { fail }
  Given(/^this step is a table step$/) {|t| }
  STEPS
end

Given('a file named {string} with:') do |path, content|
  write_file(path, content)
end

Given('an empty file named {string}') do |path|
  write_file(path, '')
end

Given('the following profiles are defined:') do |profiles|
  write_file('cucumber.yml', profiles)
end

When('I run `cucumber{}`') do |args|
  @cucumber.execute(args)
  Dir.chdir('../..')
end

Then('the exit status should be {int}') do |status|
  expect(@cucumber.exit_status).to eq(status)
end

Then('it should fail') do
  expect(@cucumber.exit_status).not_to eq(0)
end

Then('it should fail with:') do |output|
  #expect(@cucumber.exit_status).not_to eq(0)
  output_include(@cucumber.all_output, output)
end

Then('it should fail with exactly:') do |output|
  #expect(@cucumber.exit_status).not_to eq(0)
  output_equals(@cucumber.all_output, output)
end

Then('it should pass') do
  expect(@cucumber.exit_status).to eq(0)
end

Then('it should pass with:') do |output|
  #expect(@cucumber.exit_status).to eq(0)
  output_include(@cucumber.all_output, output)
end

Then('it should pass with exactly:') do |output|
  output_equals(@cucumber.all_output, output)
end

Then('the output should contain:') do |output|
  output_include(@cucumber.all_output, output)
end

Then('the output should not contain:') do |output|
  output_include_not(@cucumber.all_output, output)
end

Then('the stderr should contain:') do |output|
  output_include(@cucumber.stderr, output)
end

Then('the stderr should not contain anything') do
  expect(@cucumber.stderr).to be_empty
end

Then('the {word} profile should be used') do |profile|
  output_include(@cucumber.all_output, profile)
end

Then('exactly these files should be loaded: {list}') do |files|
  expect(@cucumber.stdout.scan(/^  \* (.*\.rb)$/).flatten).to eq files
end

Then('exactly these features should be run: {list}') do |files|
  expect(@cucumber.stdout.scan(/^  \* (.*\.feature)$/).flatten).to eq files
end

Then('{string} should not be required') do |file_name|
  expect(@cucumber.stdout).not_to include("* #{file_name}")
end

Then('{string} should be required') do |file_name|
  expect(@cucumber.stdout).to include("* #{file_name}")
end

Then('it fails before running features with:') do |expected|
  output_starts_with(@cucumber.all_output, expected)
  expect(@cucumber.exit_status).not_to eq(0)
end