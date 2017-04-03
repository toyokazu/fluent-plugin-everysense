# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-everysense"
  spec.version       = "0.1.0"
  spec.authors       = ["Toyokazu Akiyama"]
  spec.email         = ["toyokazu@gmail.com"]

  spec.summary       = %q{Fluent Input/Output plugin for EverySense Framework}
  spec.description   = %q{Fluent Input/Output plugin for EverySense Framework}
  spec.homepage      = "https://github.com/toyokazu/fluent-plugin-everysense"
  spec.license       = "Apache License Version 2.0"

  spec.files         = `git ls-files`.gsub(/.+images\/[\w\.-]+\n/, "").split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_dependency 'fluentd', '~> 0.14.0'
  #spec.add_dependency 'fluentd', '~> 0.12.0'
  #spec.add_dependency 'fluentd', '>= 0.10.0'

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
