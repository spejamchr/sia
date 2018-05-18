
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sia/version"

Gem::Specification.new do |spec|
  spec.name          = "sia"
  spec.version       = Sia::VERSION
  spec.authors       = ["Spencer Christiansen"]
  spec.email         = ["jc.spencer92@gmail.com"]

  spec.summary       = %q{Encrypt files with digital safes}
  spec.homepage      = "https://github.com/spejamchr/sia/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.11"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.3.0"
end
