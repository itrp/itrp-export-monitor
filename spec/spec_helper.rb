# -*- encoding : utf-8 -*-
dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir + '/../lib'
$LOAD_PATH.unshift dir

STDERR.puts("Running specs using ruby version #{RUBY_VERSION}")

require 'simplecov'
SimpleCov.start

require 'rspec'
require 'webmock/rspec'

require 'itrp/export/monitor'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir["#{dir}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.before(:each) do
    @spec_dir = File.dirname(__FILE__)

    # create /spec/log directory
    log_dir = @spec_dir + '/log'
    Dir.mkdir(log_dir) unless File.exists?(log_dir)
    # and log to /spec/log/test.log by default
    Itrp::Export::Monitor.configuration.logger = Logger.new("#{log_dir}/test.log")

    # delete csv and genereated rb files in the /spec/tmp directory
    Dir.glob("#{@spec_dir}/tmp/**/*.{csv,rb}").each{ |f| File.delete(f) }

    @fixture_dir = "#{dir}/support/fixtures"
  end
  config.after(:each) { Itrp::Export::Monitor.configuration.reset }

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

end

