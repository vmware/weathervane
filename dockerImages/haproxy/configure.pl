#!/usr/bin/perl

use strict;
use POSIX;

my $httpPort        = $ENV{'HAPROXY_HTTP_PORT'};
my $httpsPort       = $ENV{'HAPROXY_HTTPS_PORT'};
my $statsPort       = $ENV{'HAPROXY_STATS_PORT'};
my $maxConn         = $ENV{'HAPROXY_MAXCONN'};
my $serverMaxConn   = $ENV{'HAPROXY_SERVER_MAXCONN'};
my $serverHostnames = $ENV{'HAPROXY_SERVER_HOSTNAMES'};
my @serverHostnames = split /,/, $serverHostnames;

print "configure haproxy. \n";
open( FILEIN, "/root/haproxy/haproxy.cfg" )
  or die "Can't open file /root/haproxy/haproxy.cfg: $!";
open( FILEOUT, ">/etc/haproxy/haproxy.cfg" )
  or die "Can't open file /etc/haproxy/haproxy.cfg: $!";
while ( my $inline = <FILEIN> ) {

	if ( $inline =~ /^\s*backend\s/ ) {
		print FILEOUT $inline;
		while ( $inline = <FILEIN> ) {

			if ( $inline =~ /^\s*server\s/ ) {

				# Parse the port number and any other keywords
				$inline =~ /\:(\d+)(\s.*)$/;
				my $endLine  = $2;
				my $filePort = $1;

				# suck up all of the old server lines until the next
				# non-server line.
				while ( $inline = <FILEIN> ) {
					if ( !( $inline =~ /^\s*server\s/ ) ) {
						last;
					}
				}

				# Output server lines for each web server, then
				# add the line that was read after the server lines
				my $cnt = 1;
				foreach my $hostname (@serverHostnames) {
					my $port;
					if ( $filePort == 80 ) {
						$port = $httpPort;
					}
					else {
						$port = $httpsPort;
					}
					print FILEOUT "    server web"
					  . $cnt
					  . " $hostname:$port"
					  . $endLine
					  . " maxconn $serverMaxConn " . "\n";
					$cnt++;
				}

				if ( $inline && !( $inline =~ /^\s*server\s/ ) ) {
					print FILEOUT $inline;
				}
				last;
			}
			else {
				print FILEOUT $inline;
			}

		}
	}
	elsif ( $inline =~ /maxconn/ ) {
		print FILEOUT "    maxconn\t" . $maxConn . "\n";
	}
	elsif ( $inline =~ /bind\s+\*\:10080/ ) {
		print FILEOUT "        bind *:" . $statsPort . "\n";
	}
	elsif ( $inline =~ /bind\s+\*\:80/ ) {
		print FILEOUT "        bind *:" . $httpPort . "\n";
	}
	elsif ( $inline =~ /bind\s+\*\:443/ ) {
		print FILEOUT "        bind *:" . $httpsPort . "\n";
	}
	elsif ( $inline =~ /^\s*listen.*ssh\s/ ) {

		# we are at the ssh forwarders section.
		# suck up everything through the end of the file and then
		# put the new forwarders in
		last;
	}
	else {
		print FILEOUT $inline;
	}
}

close FILEIN;
close FILEOUT;