# -*- encoding: utf-8 -*-
# stub: activerecord 1.13.2 ruby lib

Gem::Specification.new do |s|
  s.name = "activerecord".freeze
  s.version = "1.13.2".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.autorequire = "active_record".freeze
  s.date = "2005-12-13"
  s.description = "Implements the ActiveRecord pattern (Fowler, PoEAA) for ORM. It ties database tables and classes together for business objects, like Customer or Subscription, that can find, save, and destroy themselves without resorting to manual SQL.".freeze
  s.email = "david@loudthinking.com".freeze
  s.extra_rdoc_files = ["README".freeze]
  s.files = ["README".freeze]
  s.homepage = "http://www.rubyonrails.org".freeze
  s.rdoc_options = ["--main".freeze, "README".freeze]
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0".freeze)
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Implements the ActiveRecord pattern for ORM.".freeze

  s.installed_by_version = "3.5.3".freeze if s.respond_to? :installed_by_version

  s.specification_version = 1

  s.add_runtime_dependency(%q<activesupport>.freeze, ["= 1.2.5".freeze])
end
