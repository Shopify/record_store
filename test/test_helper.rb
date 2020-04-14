require 'minitest/autorun'
require 'minitest/focus'
require 'mocha/minitest'
require 'vcr'
require 'pry'
require 'fileutils'
require 'webmock'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'record_store'

DUMMY_CONFIG_PATH = File.expand_path('fixtures/config/dummy/config.yml', __dir__)
RecordStore.config_path = DUMMY_CONFIG_PATH
Minitest::Test.include(RecordStore)

Dir[File.expand_path('support/*', __dir__)].each do |path|
  require path
end
