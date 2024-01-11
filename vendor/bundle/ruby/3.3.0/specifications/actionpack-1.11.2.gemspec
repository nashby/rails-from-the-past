# -*- encoding: utf-8 -*-
# stub: actionpack 1.11.2 ruby lib

Gem::Specification.new do |s|
  s.name = "actionpack".freeze
  s.version = "1.11.2".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.autorequire = "action_controller".freeze
  s.date = "2005-12-13"
  s.description = "Eases web-request routing, handling, and response as a half-way front, half-way page controller. Implemented with specific emphasis on enabling easy unit/integration testing that doesn't require a browser.".freeze
  s.email = "david@loudthinking.com".freeze
  s.homepage = "http://www.rubyonrails.org".freeze
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0".freeze)
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Web-flow and rendering framework putting the VC in MVC.".freeze

  s.installed_by_version = "3.5.3".freeze if s.respond_to? :installed_by_version

  s.specification_version = 1

  s.add_runtime_dependency(%q<activesupport>.freeze, ["= 1.2.5".freeze])
end
