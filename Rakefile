require 'rake'
require 'spec/rake/spectask'
require 'lib/core'

desc "Run all examples"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/**/*.rb']
end

desc "Create packages"
task :pkg4google do
  system %Q{cd .. && tar cvzf rtunnel/pkg/rtunnel-#{RTunnel::VERSION}.tar.gz rtunnel \
            --exclude=.svn --exclude=pkg --exclude=rtunnel.ipr --exclude=rtunnel.iws \
            --exclude=rtunnel.iml
            }
  system "rubyscript2exe rtunnel_server.rb --stop-immediately && 
          mv rtunnel_server_linux pkg/rtunnel_server_linux-#{RTunnel::VERSION}"
end
