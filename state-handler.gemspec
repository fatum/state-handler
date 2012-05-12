# -*- encoding: utf-8 -*-
require File.expand_path('../lib/state-handler/version', __FILE__)

Gem::Specification.new do |gem|
  gem.author       = "Maxim Filipovich"
  gem.email         = "fatumka@gmail.com"
  gem.description   = %q{State handler per object params}
  gem.summary       = %q{State handler per object params}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "state-handler"
  gem.require_paths = ["lib"]
  gem.version       = StateHandler::VERSION

  gem.add_development_dependency('rake')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('timecop')
end

