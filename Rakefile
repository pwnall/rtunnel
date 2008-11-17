require 'rubygems'
require 'echoe'
require 'rake'
require 'spec/rake/spectask'

$: << File.join(File.dirname(__FILE__), 'lib')
require 'rtunnel'

desc "Run all examples"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/**/*.rb']
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
  print RTunnel::Command.printable_codes
end

Echoe.new('rtunnel') do |p|
  p.rubyforge_name = 'coderrr'
  p.author = 'coderrr'
  p.email = 'coderrr.contact@gmail.com'
  p.summary = 'Reverse tunnel server and client.'  
  p.description = ''
  p.url = 'http://code.google.com/p/rtunnel/'
  # p.remote_rdoc_dir = '' # Release to root
  p.dependencies = ["eventmachine >=0.12.2",
                    "net-ssh >=2.0.4",
                    "uuidtools >=1.0.2"]
  p.development_dependencies = ["echoe >=3.0.1",
                                "rspec >=1.1.11",
                                "simple-daemon >=0.1.2",
                                "thin >=1.0.0"]
  p.need_tar_gz = false
  p.need_zip = false
end