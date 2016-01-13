require 'simplecov'
SimpleCov.start
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'publish_to_web'
require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:each) do
    SKVS.adapter = SKVS::MemoryAdapter.new
  end
end
