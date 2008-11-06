INSTALL
-

on server and local machine:

`gem sources -a http://gems.github.com`

`sudo gem install coderrr-rtunnel`

If you don't have root access on server, you can use either the rtunnel_server_linux binary (only works with linux), or extract the .tar.gz and use `rtunnel_server.rb` (all function the same)

USAGE
-

on server (myserver.com):

`rtunnel_server`

on your local machine:

`rtunnel_client -c myserver.com -f 4000 -t 3000`

This would reverse tunnel myserver.com:4000 to localhost:3000 so that if you had a web server running at port 3000 on your local machine, anyone on the internet could access it by going to http://myserver.com:4000

**News**

  * 0.3.6 released, new protocol
  * created gem for easier installation
  * 0.2.1 released, minor bugfix, cmdline options change
  * 0.2.0 released, much simpler
  * 0.1.2 released
  * Created rtunnel_server binary for linux so you don't need Ruby installed on the host you want to reverse tunnel from
  * 0.1.1 released
  * Added default control port of 19050, no longer have to specify this on client or server unless you care to change it

RTunnel?
-

This client/server allow you to reverse tunnel traffic.  Reverse tunneling is useful if you want to run a server behind a NAT and you do not have the ability use port forwarding.  The specific reason I created this program was to reduce the pain of Facebook App development on a crappy internet connection that drops often.  ssh -R was not cutting it.

**How does reverse tunneling work?**

  * tunnel\_client makes connection to tunnel\_server (through NAT)
  * tunnel_server listens on port X
  * internet_user connects to port X on tunnel server
  * tunnel\_server uses existing connection to tunnel internet user's request back to tunnel\_client
  * tunnel_client connects to local server on port Y
  * tunnel_client tunnels internet users connection through to local server

or:

  * establish connection: tunnel\_client --NAT--> tunnel\_server
  * reverse tunnel: internet\_user -> tunnel_server --(NAT)--> tunnel\_client -> server\_running\_behind\_nat

**How is this different than normal tunneling?**

With tunneling, usually your connections are made in the same direction you create the tunnel connection.  With reverse tunneling, you tunnel your connections the opposite direction of which you made the tunnel connection.  So you initiate the tunnel with A -> B, but connections are tunneled from B -> A.

**Why not just use ssh -R?**

The same thing can be achieved with ssh -R, why not just use it?  A lot of ssh servers don't have the GatewayPorts sshd option set up to allow you to reverse tunnel.  If you are not in control of the server and it is not setup correctly then you are SOL.  RTunnel does not require you are in control of the server.  ssh -R has other annoyances.  When your connection drops and you try to re-initiate the reverse tunnel sometimes you get an address already in use error because the old tunnel process is still laying around.  This requires you to kill the existing sshd process.  RTunnel does not have this problem.