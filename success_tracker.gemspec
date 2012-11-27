# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'success_tracker/version'

Gem::Specification.new do |gem|
  gem.name          = "success_tracker"
  gem.version       = SuccessTracker::VERSION
  gem.authors       = ["Michael Raidel"]
  gem.email         = ["raidel@induktiv.at"]
  gem.description   = %q{SuccessTracker allows you to track success and failure of tasks}
  gem.summary       = %q{SuccessTracker allows you to track success and failure of tasks and define thresholds for unexpected failure conditions.}

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency "redis"
  gem.add_development_dependency "shoulda"
  gem.add_development_dependency "rake"
end
