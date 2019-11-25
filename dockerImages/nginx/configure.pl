#!/usr/bin/perl
# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;

my $workerConnections    = $ENV{'WORKERCONNECTIONS'};
my $perServerConnections = $ENV{'PERSERVERCONNECTIONS'};
my $keepaliveTimeout     = $ENV{'KEEPALIVETIMEOUT'};
my $maxKeepaliveRequests = $ENV{'MAXKEEPALIVEREQUESTS'};
my $cacheMaxSize     = $ENV{'CACHEMAXSIZE'};
my $appServersString     = $ENV{'APPSERVERS'};
my @appServers           = split( /,/, $appServersString );
my $bidServersString     = $ENV{'BIDSERVERS'};
my @bidServers           = split( /,/, $bidServersString );
my $imageStoreType       = $ENV{'IMAGESTORETYPE'};
my $httpPort             = $ENV{'HTTPPORT'};
my $httpsPort            = $ENV{'HTTPSPORT'};

# Modify nginx.conf and then copy to web server
open( FILEIN, "/root/nginx/nginx.conf" )
  or die "Can't open file /etc/nginx/nginx.conf: $!";
open( FILEOUT, ">/tmp/nginx.conf" )
  or die "Can't open file /tmp/nginx.conf: $!";

while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /[^\$]upstream\sapp/ ) {
		print FILEOUT $inline;
		print FILEOUT "least_conn;\n";
		do {
			$inline = <FILEIN>;
		} while ( !( $inline =~ /}/ ) );

		# Add the balancer lines for each app server
		foreach my $appServer (@appServers) {
			print FILEOUT "      server $appServer max_fails=0 max_conns=$perServerConnections ;\n";
		}
		print FILEOUT "      keepalive 1000;";
		print FILEOUT "    }\n";
	}
	elsif ( $inline =~ /[^\$]upstream\sbid/ ) {
		print FILEOUT $inline;
		print FILEOUT "least_conn;\n";
		do {
			$inline = <FILEIN>;
		} while ( !( $inline =~ /}/ ) );
		
		if ($#bidServers >= 0) {
			# Add the balancer lines for each bid server
			foreach my $bidServer (@bidServers) {
				print FILEOUT "      server $bidServer max_fails=0 max_conns=$perServerConnections ;\n";
			}
		} else {
			# if no bid server, then bid requests go to app servers
			foreach my $appServer (@appServers) {
				print FILEOUT "      server $appServer max_fails=0 max_conns=$perServerConnections ;\n";
			}			
		}
		print FILEOUT "      keepalive 1000;";
		print FILEOUT "    }\n";
	}
	elsif ( $inline =~ /^(\s*)proxy_cache_path\s/ ) {
		print FILEOUT "${1}proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=one:100m max_size=" . $cacheMaxSize . " inactive=2h;\n";
	}
	elsif ( $inline =~ /^(\s*)worker_connections\s/ ) {
		print FILEOUT "${1}worker_connections " . $workerConnections . ";\n";
	}
	elsif ( $inline =~ /^(\s*)keepalive_timeout\s/ ) {
		print FILEOUT "${1}keepalive_timeout " . $keepaliveTimeout . ";\n";
	}
	elsif ( $inline =~ /^(\s*)keepalive_requests\s/ ) {
		print FILEOUT "${1}keepalive_requests " . $maxKeepaliveRequests . ";\n";
	}
	else {
		print FILEOUT $inline;
	}

}

close FILEIN;
close FILEOUT;

# Push the config file to the docker container
`mv /tmp/nginx.conf /etc/nginx/nginx.conf`;

# Modify ssl.conf and then copy to web server
open( FILEIN, "/root/nginx/conf.d/ssl.conf" )
  or die "Can't open file /etc/nginx/conf.d/ssl.conf: $!";
open( FILEOUT, ">/tmp/ssl.conf" )
  or die "Can't open file /tmp/ssl.conf: $!";

while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /rewrite rules go here/ ) {
		print FILEOUT $inline;
	}
	elsif ( $inline =~ /^\s*listen\s+443/ ) {
		print FILEOUT "    listen   " . $httpsPort . " ssl backlog=16384 ;\n";
	}
	else {
		print FILEOUT $inline;
	}

}

close FILEIN;
close FILEOUT;

`mv /tmp/ssl.conf /etc/nginx/conf.d/ssl.conf`;

open( FILEIN, "/root/nginx/conf.d/default.conf" )
  or die "Can't open file /etc/nginx/conf.d/default.conf: $!";
open( FILEOUT, ">/tmp/default.conf" )
  or die "Can't open file /tmp/default.conf: $!";

while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /rewrite rules go here/ ) {
		print FILEOUT $inline;
	}
	elsif ( $inline =~ /^\s*listen\s+80/ ) {
		print FILEOUT "    listen   " . $httpPort
		  . " backlog=16384 ;\n";
	}
	else {
		print FILEOUT $inline;
	}

}

`mv /tmp/default.conf /etc/nginx/conf.d/default.conf`;

