Gem::Specification.new do |s|
  s.name     = "rtunnel"
  s.version  = "0.3.8"
  s.summary  = "reverse tunnel server and client"
  s.email    = "coderrr.contact@gmail.com"
  s.homepage = "http://github.com/coderrr/rtunnel"
  s.description = "reverse tunnel server and client"
  s.has_rdoc = false
  s.authors  = ["coderrr"]
  s.files    = [
    "lib/rtunnel_server_cmd.rb", "lib/client.rb", "lib/core.rb", "lib/rtunnel_client_cmd.rb", "lib/server.rb", "lib/cmds.rb", "bin/rtunnel_server", "bin/rtunnel_client",
   "ab_test.rb", "README.markdown", "rtunnel.gemspec", "stress_test.rb", "Rakefile", "rtunnel_client.rb", "rtunnel_server.rb" 
    ]
  s.test_files = [
    "spec/integration_spec.rb", "spec/spec_helper.rb", "spec/client_spec.rb", "spec/cmds_spec.rb", "spec/server_spec.rb"
  ]
  s.add_dependency("uuidtools", [">= 1.0.2"])
  s.add_dependency("facets", [">= 2.1.2"])
end
