# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

# Codecov is enabled when CI is set to true
if ENV['CI'] == 'true'
  puts 'Enabling Simplecov to upload code coverage results to codecov.io'
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/test/' # Exclude test directory from coverage
    add_filter '/spec/' # Exclude spec directory from coverage
    add_filter '/config/' # Exclude config directory from coverage

    # Add any additional filters or exclusions if needed
    # add_filter '/other_directory/'

    add_group 'Lib', '/lib' # Include the lib directory for coverage
    puts "Tracked files: #{SimpleCov.tracked_files}"
  end

  require 'simplecov-cobertura'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
end

require 'active_record/railtie'
require 'action_controller/railtie'
require 'rspec/rails'

require 'activerecord_multi_tenant'

require 'bundler'
Bundler.require(:default, :development)
require_relative './support/format_sql'

dbconfig = YAML.safe_load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), 'debug.log'))
ActiveRecord::Base.establish_connection(dbconfig['test'])

RSpec.configure do |config|
  config.infer_base_class_for_anonymous_controllers = true
  config.use_transactional_fixtures = false
  config.filter_run_excluding type: :controller unless Object.const_defined?(:ActionController)

  config.after(:each) do
    MultiTenant.current_tenant = nil
  end

  config.before(:suite) do
    MultiTenant::FastTruncate.run
  end

  config.after(:each) do
    MultiTenant::FastTruncate.run
  end
end

module MultiTenantTest
  class Application < Rails::Application; end
end

MultiTenantTest::Application.config.secret_token = 'x' * 40
MultiTenantTest::Application.config.secret_key_base = 'y' * 40

# rubocop:disable Lint/UnusedMethodArgument
# changing the name of the parameter breaks tests
def with_belongs_to_required_by_default(&block)
  default_value = ActiveRecord::Base.belongs_to_required_by_default
  ActiveRecord::Base.belongs_to_required_by_default = true
  yield
ensure
  ActiveRecord::Base.belongs_to_required_by_default = default_value
end
# rubocop:enable Lint/UnusedMethodArgument
require 'schema'
