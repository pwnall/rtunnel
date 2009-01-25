Gem::Specification.new do |s|
  s.name = 'rtunnel'
  s.version = '0.4.0'
  s.authors = ['coderrr', 'costan']
  s.email = 'coderrr.contact@gmail.com'
  s.summary = 'Reverse tunnel server and client.'  
  s.description = ''
  s.homepage = 'http://github.com/coderrr/rtunnel'
  s.add_dependency('eventmachine', '>=0.12.2')
  s.add_dependency('net-ssh', '>=2.0.4')
  s.files = %w(
    CHANGELOG
    LICENSE
    Manifest
    README.markdown
    Rakefile
    bin/rtunnel_client
    bin/rtunnel_server
    lib/rtunnel.rb
    lib/rtunnel/client.rb
    lib/rtunnel/command_protocol.rb
    lib/rtunnel/commands.rb
    lib/rtunnel/core.rb
    lib/rtunnel/crypto.rb
    lib/rtunnel/frame_protocol.rb
    lib/rtunnel/io_extensions.rb
    lib/rtunnel/leak.rb
    lib/rtunnel/rtunnel_client_cmd.rb
    lib/rtunnel/rtunnel_server_cmd.rb
    lib/rtunnel/server.rb
    lib/rtunnel/socket_factory.rb
    lib/rtunnel/connection_id.rb
    lib/rtunnel/command_processor.rb
    spec/client_spec.rb
    spec/cmds_spec.rb
    spec/integration_spec.rb
    spec/server_spec.rb
    spec/spec_helper.rb
    test/command_stubs.rb
    test/protocol_mocks.rb
    test/scenario_connection.rb
    test/test_client.rb
    test/test_command_protocol.rb
    test/test_commands.rb
    test/test_crypto.rb
    test/test_frame_protocol.rb
    test/test_io_extensions.rb
    test/test_server.rb
    test/test_socket_factory.rb
    test/test_tunnel.rb
    test/test_connection_id.rb
    test_data/known_hosts
    test_data/ssh_host_rsa_key
    test_data/random_rsa_key
    test_data/ssh_host_dsa_key
    test_data/authorized_keys2
    tests/_ab_test.rb
    tests/_stress_test.rb
    tests/lo_http_server.rb
  )
  s.executables = ['rtunnel_client', 'rtunnel_server']
end
