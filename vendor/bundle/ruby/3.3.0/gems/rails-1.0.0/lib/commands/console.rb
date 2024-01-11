irb = RUBY_PLATFORM =~ /mswin32/ ? 'irb.bat' : 'irb'

require 'optparse'
options = { :sandbox => false, :irb => irb }
OptionParser.new do |opt|
  opt.banner = "Usage: console [environment] [options]"
  opt.on('-s', '--sandbox', 'Rollback database modifications on exit.') { |options[:sandbox]| }
  opt.on("--irb=[#{irb}]", 'Invoke a different irb.') { |options[:irb]| }
  opt.parse!(ARGV)
end

libs =  " -r irb/completion"
libs << " -r #{RAILS_ROOT}/config/environment"
libs << " -r console_sandbox" if options[:sandbox]

ENV['RAILS_ENV'] = ARGV.first || 'development'
if options[:sandbox]
  puts "Loading #{ENV['RAILS_ENV']} environment in sandbox."
  puts "Any modifications you make will be rolled back on exit."
else
  puts "Loading #{ENV['RAILS_ENV']} environment."
end
exec "#{options[:irb]} #{libs} --prompt-mode simple"
