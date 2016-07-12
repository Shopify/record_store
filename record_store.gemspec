lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'record_store/version'

Gem::Specification.new do |spec|
  spec.name        = 'record_store'
  spec.version     = RecordStore::VERSION
  spec.authors     = ['Willem van Bergen', 'Emil Stolarsky']
  spec.email       = ['willem@railsdoctors.com', 'emil@shopify.com']

  spec.summary     = 'Manage DNS using git'
  spec.description = "Manage DNS through a git-based workflow. If you're looking for the original 'record_store', that has been renamed to 'sequel_record_store'."
  spec.homepage    = 'https://github.com/Shopify/record_store'
  spec.license     = 'MIT'

  spec.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|DESIGN)}) }
  spec.executables = ['record-store']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0'

  spec.add_runtime_dependency 'thor'
  spec.add_runtime_dependency 'activesupport', '~> 4.2'
  spec.add_runtime_dependency 'activemodel', '~> 4.2'
  spec.add_runtime_dependency 'fog'
  spec.add_runtime_dependency 'fog-json'
  spec.add_runtime_dependency 'fog-xml'
  spec.add_runtime_dependency 'fog-dynect'
  spec.add_runtime_dependency 'ejson'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'pry'
end
