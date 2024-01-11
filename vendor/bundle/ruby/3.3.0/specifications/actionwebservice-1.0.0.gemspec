# -*- encoding: utf-8 -*-
# stub: actionwebservice 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "actionwebservice".freeze
  s.version = "1.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Leon Breedt".freeze]
  s.autorequire = "action_web_service".freeze
  s.date = "2005-12-13"
  s.description = "Adds WSDL/SOAP and XML-RPC web service support to Action Pack".freeze
  s.email = "bitserf@gmail.com".freeze
  s.homepage = "http://www.rubyonrails.org".freeze
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0".freeze)
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Web service support for Action Pack.".freeze

  s.installed_by_version = "3.5.3".freeze if s.respond_to? :installed_by_version

  s.specification_version = 1

  s.add_runtime_dependency(%q<actionpack>.freeze, ["= 1.11.2".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, ["= 1.13.2".freeze])
end
