$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'publish_to_web'

RSpec.configure do |config|
  config.before(:each) do
    SKVS.adapter = SKVS::MemoryAdapter.new
  end
end
