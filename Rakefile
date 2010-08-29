require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|    
    gem.name = 'rtunnel'
    gem.rubyforge_project = 'rtunnel'
    gem.summary = 'Reverse tunnel server and client.'
    gem.description = "More robust than ssh's reverse tunnel mechanism.'"
    gem.email = 'coderrr.contact@gmail.com'
    gem.homepage = 'http://github.com/coderrr/rtunnel'
    gem.author = 'coderrr'    
    gem.add_runtime_dependency "eventmachine", ">= 0.12.2"
    gem.add_runtime_dependency "net-ssh", ">= 2.0.4"
    gem.add_development_dependency "rspec", ">= 1.3.0"
    gem.add_development_dependency "simple-daemon", ">= 0.1.2"
    gem.add_development_dependency "thin", ">= 1.0.0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "authpwn_rails #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('app/**/*.rb')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Create packages"
task :pkg4google do
  system %Q{cd .. && tar cvzf rtunnel/pkg/rtunnel-#{RTunnel::VERSION}.tar.gz \
            rtunnel --exclude=.svn --exclude=pkg --exclude=rtunnel.ipr \
            --exclude=rtunnel.iws --exclude=rtunnel.iml
            }
  system "rubyscript2exe rtunnel_server.rb --stop-immediately && 
          mv rtunnel_server_linux pkg/rtunnel_server_linux-#{RTunnel::VERSION}"
end

desc "Print command codes"
task :codes do
  $: << File.expand_path('../lib', __FILE__)
  require 'rtunnel'
  print RTunnel::Command.printable_codes
end
