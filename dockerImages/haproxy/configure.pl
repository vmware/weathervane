#!/usr/bin/perl

use strict;
use POSIX;

my $httpPort        = $ENV{'HAPROXY_HTTP_PORT'};
my $httpsPort       = $ENV{'HAPROXY_HTTPS_PORT'};
my $statsPort       = $ENV{'HAPROXY_STATS_PORT'};
my $maxConn         = $ENV{'HAPROXY_MAXCONN'};
my $serverMaxConn   = $ENV{'HAPROXY_SERVER_MAXCONN'};
my $httpHostnames = $ENV{'HAPROXY_SERVER_HTTPHOSTNAMES'};
my $httpsHostnames = $ENV{'HAPROXY_SERVER_HTTPSHOSTNAMES'};
my @httpHostnames = split /,/, $httpHostnames;
my @httpsHostnames = split /,/, $httpsHostnames;
my $terminateTLS =  $ENV{'HAPROXY_TERMINATETLS'};
my $nbProc =  $ENV{'HAPROXY_NBPROC'};

print "configure haproxy. \n";

my $configFileName = "/root/haproxy/haproxy.cfg";
if ($terminateTLS) {
	$configFileName = "/root/haproxy/haproxy.cfg.terminateTLS";
}
open( FILEIN, "$configFileName" )
  or die "Can't open file $configFileName: $!";
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
				if ( $filePort == 80 ) {
					foreach my $hostname (@httpHostnames) {
						print FILEOUT "    server web"
						  . $cnt	  . " $hostname "
					  	. $endLine
					  	. " maxconn $serverMaxConn " . "\n";
						$cnt++;
					}
				}
				else {
					foreach my $hostname (@httpsHostnames) {
						print FILEOUT "    server web"
						  . $cnt	  . " $hostname "
					  	. $endLine
					  	. " maxconn $serverMaxConn " . "\n";
						$cnt++;
					}
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
	elsif ( $inline =~ /nbproc/ ) {
		print FILEOUT "    nbproc $nbProc\n";
	}
	elsif ( $inline =~ /bind\s+\*\:10080/ ) {
		print FILEOUT "        bind *:" . $statsPort . "\n";
	}
	elsif ( $inline =~ /bind\s+\*\:80/ ) {
		print FILEOUT "        bind *:" . $httpPort . "\n";
	}
	elsif ( $inline =~ /bind\s+\*\:443/ ) {
		my $tlsTerminationString = "";
		if ($terminateTLS) {
			$tlsTerminationString = " ssl crt /etc/pki/tls/private/weathervane.pem";
		}
		print FILEOUT "        bind *:" . $httpsPort . "$tlsTerminationString\n";
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
