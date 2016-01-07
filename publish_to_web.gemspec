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
  spec.homepage      = "https://www.protonet.info"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "net-ssh", "~> 3.0"
  spec.add_runtime_dependency "http",    "~> 1.0"
  spec.add_runtime_dependency "sshkey",  "~> 1.8.0"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
