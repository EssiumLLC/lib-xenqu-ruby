# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Ben Olson"]
  gem.email         = ["ben.olson@essium.co"]
  gem.description   = %q{Foundation library for accessing Xenqu REST API.}
  gem.summary       = %q{Xenqu API Library}

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "lib-xenqu"
  gem.require_paths = ["lib"]
  gem.version       = "0.1"

  gem.add_dependency 'rest-client', '~> 2.0.0.rc2'
  gem.add_dependency 'simple_oauth'
  gem.add_development_dependency 'rspec', '~> 2.7'
end
