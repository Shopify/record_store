lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'record_store/version'

Gem::Specification.new do |spec|
  spec.name        = 'record_store'
  spec.version     = RecordStore::VERSION
  spec.authors     = ['Willem van Bergen', 'Emil Stolarsky']
  spec.email       = ['willem@railsdoctors.com', 'emil@shopify.com']

  spec.summary     = 'Manage DNS using git'
  spec.description = "Manage DNS through a git-based workflow. If you're looking for the original 'record_store', " \
    "that has been renamed to 'sequel_record_store'."
  spec.homepage    = 'https://github.com/Shopify/record_store'
  spec.license     = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files       = %x(git ls-files -z).split("\x0").reject { |f| f.match(/^(test|DESIGN)/) }
  spec.executables = ['record-store']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0.0'

  spec.add_runtime_dependency 'activemodel', '>= 4.2'
  spec.add_runtime_dependency 'activesupport', '>= 4.2'
  spec.add_runtime_dependency 'ejson'
  spec.add_runtime_dependency 'thor', '>= 0.20.3', '< 1.4.0'

  spec.add_runtime_dependency 'dnsimple', '>= 4.4', '< 9.1'
  spec.add_runtime_dependency 'fog-dynect', '>= 0.4', '< 0.6'
  spec.add_runtime_dependency 'fog-json'
  spec.add_runtime_dependency 'fog-xml'
  spec.add_runtime_dependency 'google-cloud-dns', '>= 0.31', '< 2.0'
  spec.add_runtime_dependency 'ns1'
  spec.add_runtime_dependency 'oci', '>= 2.14', '< 2.22'
  spec.add_runtime_dependency 'ruby-limiter', '>= 1.0.1', '< 3'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'minitest-focus'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop', '~> 1.68.0'
  spec.add_development_dependency 'rubocop-shopify', '~> 2.15.1'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'
end
