require 'rake/testtask'
require 'bundler/gem_tasks'

$LOAD_PATH.unshift(__dir__ + "/lib")
require 'record_store'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end

task :validate do
  record_store = RecordStore::CLI.new
  record_store.validate_records
  record_store.validate_all_present
end

task default: [:test]
