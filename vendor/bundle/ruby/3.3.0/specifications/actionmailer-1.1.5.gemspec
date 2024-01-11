# -*- encoding: utf-8 -*-
# stub: actionmailer 1.1.5 ruby lib

Gem::Specification.new do |s|
  s.name = "actionmailer".freeze
  s.version = "1.1.5".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.autorequire = "action_mailer".freeze
  s.date = "2005-12-13"
  s.description = "Makes it trivial to test and deliver emails sent from a single service layer.".freeze
  s.email = "david@loudthinking.com".freeze
  s.homepage = "http://www.rubyonrails.org".freeze
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0".freeze)
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Service layer for easy email delivery and testing.".freeze

  s.installed_by_version = "3.5.3".freeze if s.respond_to? :installed_by_version

  s.specification_version = 1

  s.add_runtime_dependency(%q<actionpack>.freeze, ["= 1.11.2".freeze])
end
