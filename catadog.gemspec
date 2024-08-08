# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "catadog"
  s.version = "0.1.0"
  s.licenses = ["BSD-3-Clause", "Apache-2.0"]
  s.summary = "Datadog wire introspection tool"
  s.description = "Intercept and analyse Datadog communication"
  s.authors = ["Datadog, Inc."]
  s.email = "dev@datadoghq.com"
  s.files = [
    "bin/catadog"
  ] + Dir.glob("lib/**/*.rb") + Dir.glob("mocks/**/*.rb")
  s.bindir = "bin"
  s.executables = "catadog"
  s.homepage = "https://github.com/DataDog/catadog"
  s.metadata = {
    "rubygems_mfa_required" => "true",
    "allowed_push_host" => "https://rubygems.org",
    "source_code_uri" => s.homepage
  }

  s.required_ruby_version = ">= 3.0"

  s.add_dependency "webrick", "~> 1.8.0"
  s.add_dependency "rack", "~> 2.2"
  s.add_dependency "sinatra", "~> 3.0"
  s.add_dependency "json"
  s.add_dependency "msgpack"
end
