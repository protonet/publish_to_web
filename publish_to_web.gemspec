# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'publish_to_web/version'

Gem::Specification.new do |spec|
  spec.name          = "publish_to_web"
  spec.version       = PublishToWeb::VERSION
  spec.authors       = ["Christoph Olszowka"]
  spec.email         = ["christoph@olszowka.de"]

  spec.summary       = %q{Handle Protonet PublishToWeb Connection}
  spec.description   = %q{Handle Protonet PublishToWeb Connection}
  spec.homepage      = "https://github.com/protonet/publish_to_web"

  spec.licenses      = ['MIT']

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "net-ssh",        "~> 3.0"
  spec.add_runtime_dependency "http",           "~> 1.0"
  spec.add_runtime_dependency "sshkey",         "~> 1.8.0"
  spec.add_runtime_dependency "platform-skvs",  "~> 0.4.0"
  spec.add_runtime_dependency "rainbow",        "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 1.22"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "guard-rspec", "~> 4.6"
  spec.add_development_dependency "guard-bundler", "~> 2.1"
end
