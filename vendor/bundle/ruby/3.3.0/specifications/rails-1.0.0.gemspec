# -*- encoding: utf-8 -*-
# stub: rails 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rails".freeze
  s.version = "1.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2005-12-13"
  s.description = "Rails is a framework for building web-application using CGI, FCGI, mod_ruby, or WEBrick on top of either MySQL, PostgreSQL, SQLite, DB2, SQL Server, or Oracle with eRuby- or Builder-based templates.".freeze
  s.email = "david@loudthinking.com".freeze
  s.executables = ["rails".freeze]
  s.files = ["bin/rails".freeze]
  s.homepage = "http://www.rubyonrails.org".freeze
  s.rdoc_options = ["--exclude".freeze, ".".freeze]
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0".freeze)
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Web-application framework with template engine, control-flow layer, and ORM.".freeze

  s.installed_by_version = "3.5.3".freeze if s.respond_to? :installed_by_version

  s.specification_version = 1

  s.add_runtime_dependency(%q<rake>.freeze, [">= 0.6.2".freeze])
  s.add_runtime_dependency(%q<activesupport>.freeze, ["= 1.2.5".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, ["= 1.13.2".freeze])
  s.add_runtime_dependency(%q<actionpack>.freeze, ["= 1.11.2".freeze])
  s.add_runtime_dependency(%q<actionmailer>.freeze, ["= 1.1.5".freeze])
  s.add_runtime_dependency(%q<actionwebservice>.freeze, ["= 1.0.0".freeze])
end
