#!/usr/bin/perl

use strict;

my $workerConnections    = $ENV{'WORKERCONNECTIONS'};
my $perServerConnections = $ENV{'PERSERVERCONNECTIONS'};
my $keepaliveTimeout     = $ENV{'KEEPALIVETIMEOUT'};
my $maxKeepaliveRequests = $ENV{'MAXKEEPALIVEREQUESTS'};
my $appServersString     = $ENV{'APPSERVERS'};
my @appServers           = split( /,/, $appServersString );
my $imageStoreType       = $ENV{'IMAGESTORETYPE'};
my $httpPort             = $ENV{'HTTPPORT'};
my $httpsPort            = $ENV{'HTTPSPORT'};

# Modify nginx.conf and then copy to web server
open( FILEIN, "/root/nginx/nginx.conf" )
  or die "Can't open file /etc/nginx/nginx.conf: $!";
open( FILEOUT, ">/tmp/nginx.conf" )
  or die "Can't open file /tmp/nginx.conf: $!";

while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /[^\$]upstream/ ) {
		print FILEOUT $inline;
		print FILEOUT "least_conn;\n";
		do {
			$inline = <FILEIN>;
		} while ( !( $inline =~ /}/ ) );

		# Add the balancer lines for each app server
		foreach my $appServer (@appServers) {
			print FILEOUT "      server $appServer max_fails=0 ;\n";
		}
		print FILEOUT "      keepalive 1000;";
		print FILEOUT "    }\n";
	}
	elsif ( $inline =~ /^\s*worker_connections\s/ ) {
		print FILEOUT "    worker_connections " . $workerConnections . ";\n";
	}
	elsif ( $inline =~ /^\s*keepalive_timeout\s/ ) {
		print FILEOUT "    keepalive_timeout " . $keepaliveTimeout . ";\n";
	}
	elsif ( $inline =~ /^\s*keepalive_requests\s/ ) {
		print FILEOUT "    keepalive_requests " . $maxKeepaliveRequests . ";\n";
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
		if ( $imageStoreType eq "filesystem" ) {
			print FILEOUT "if (\$query_string ~ \"size=(.*)\$\") {\n";
			print FILEOUT "set \$size \$1;\n";
			print FILEOUT
"rewrite ^/auction/image/([^\.]*)\.(.*)\$ /imageStore/\$1_\$size.\$2;\n";
			print FILEOUT "}\n";
			print FILEOUT "location /imageStore{\n";
			print FILEOUT "root /mnt;\n";
			print FILEOUT "}\n";

		}
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
		if ( $imageStoreType eq "filesystem" ) {
			print FILEOUT "if (\$query_string ~ \"size=(.*)\$\") {\n";
			print FILEOUT "set \$size \$1;\n";
			print FILEOUT
"rewrite ^/auction/image/([^\.]*)\.(.*)\$ /imageStore/\$1_\$size.\$2;\n";
			print FILEOUT "}\n";
			print FILEOUT "location /imageStore{\n";
			print FILEOUT "root /mnt;\n";
			print FILEOUT "}\n";

		}
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

