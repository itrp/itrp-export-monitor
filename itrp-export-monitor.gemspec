# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'itrp/export/monitor/version'

Gem::Specification.new do |spec|
  spec.name                  = 'itrp-export-monitor'
  spec.version               = Itrp::Export::Monitor::VERSION
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 1.9.3'
  spec.authors               = ['ITRP']
  spec.email                 = %q{developers@itrp.com}
  spec.description           = %q{Monitor a mailbox and store Scheduled ITRP Exports to disk or FTP.}
  spec.summary               = %q{The itrp-export-monitor gem makes it easy to monitor a mailbox receiving Scheduled Exports from ITRP and to store the incoming export files on disk or forward it to an FTP server.}
  spec.homepage              = 'http://help.itrp.com/help/import'
  spec.license               = 'MIT'

  spec.files = Dir.glob("lib/**/*") + %w(LICENSE.txt README.md Gemfile Gemfile.lock itrp-export-monitor.gemspec)
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  spec.require_paths = ['lib']
  spec.rdoc_options = ['--charset=UTF-8']

  spec.add_runtime_dependency 'gem_config'
  spec.add_runtime_dependency 'itrp-client'
  spec.add_runtime_dependency 'active_support'
  spec.add_runtime_dependency 'rubyzip'
  spec.add_runtime_dependency 'clacks', '>= 0.4.2'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'simplecov'
end
