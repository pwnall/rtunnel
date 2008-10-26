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

require 'rubygems'
require 'hoe'

=begin
Hoe.new('rtunnel', RTunnel::VERSION) do |p|
  p.rubyforge_name = 'coderrr'
  p.author = 'coderrr'
  p.email = 'coderrr.contact@gmail.com'
  # p.summary = 'FIX'
  # p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.remote_rdoc_dir = '' # Release to root
  p.extra_deps << ["uuidtools", ">=1.0.2"]
  p.extra_deps << ["facets", ">= 2.1.2"]
end
=end
