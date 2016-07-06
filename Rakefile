require 'rake/testtask'
require 'bundler/gem_tasks'

$LOAD_PATH.unshift(__dir__ + "/lib")
require 'recordstore'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end

task :validate do
  recordstore = RecordStore::CLI.new
  recordstore.validate_records
  recordstore.validate_all_present
end

task default: [:test]
