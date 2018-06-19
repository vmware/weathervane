#!/usr/bin/perl

use strict;
use POSIX;

my $hostname = $ENV{'HOSTNAME'};
my $completeJVMOpts  = $ENV{'TOMCAT_JVMOPTS'};
my $threads = $ENV{'TOMCAT_THREADS'};
my $connections = $ENV{'TOMCAT_JDBC_CONNECTIONS'};
my $maxIdle = $ENV{'TOMCAT_JDBC_MAXIDLE'};
my $maxConnections = $ENV{'TOMCAT_CONNECTIONS'};
my $db  = $ENV{'TOMCAT_DB_IMPL'};
my $dbHostname  = $ENV{'TOMCAT_DB_HOSTNAME'};
my $dbPort  = $ENV{'TOMCAT_DB_PORT'};
my $useTls  = $ENV{'TOMCAT_USE_TLS'};
my $httpPort  = $ENV{'TOMCAT_HTTP_PORT'};
my $httpsPort  = $ENV{'TOMCAT_HTTPS_PORT'};
my $shutdownPort  = $ENV{'TOMCAT_SHUTDOWN_PORT'};
print "configure tomcat. \n";

# Configure setenv.sh
open( FILEIN,  "/root/apache-tomcat-auction1/bin/setenv.sh" ) or die "Can't open file /root/apache-tomcat-auction1/bin/setenv.sh: $!\n";
open( FILEOUT, ">/opt/apache-tomcat-auction1/bin/setenv.sh" ) or die "Can't open file /opt/apache-tomcat-auction1/bin/setenv.sh: $!\n";
while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /^CATALINA_OPTS="(.*)"/ ) {
		print FILEOUT "CATALINA_OPTS=\"$completeJVMOpts\"\n";
	}
	else {
		print FILEOUT $inline;
	}
}
close FILEIN;
close FILEOUT;

# Configure server.xml
my $driverClassName;
if ( $db eq "mysql" ) {
	$driverClassName = "com.mysql.jdbc.Driver";
}
elsif ( $db eq "postgresql" ) {
	$driverClassName = "org.postgresql.Driver";
}

my $dbUrl;
if ( $db eq "mysql" ) {
	$dbUrl = "jdbc:mysql://" . $dbHostname . ":" . $dbPort . "/auction";
}
elsif ( $db eq "postgresql" ) {
	$dbUrl = "jdbc:postgresql://" . $dbHostname . ":" . $dbPort . "/auction";
}

open( FILEIN,  "/root/apache-tomcat-auction1/conf/server.xml") or die "Can't open file /root/apache-tomcat-auction1/conf/server.xml: $!\n";
open( FILEOUT, ">/opt/apache-tomcat-auction1/conf/server.xml" ) or die "Can't open file /opt/apache-tomcat-auction1/conf/server.xml: $!\n";
while ( my $inline = <FILEIN> ) {

	if ( $inline =~ /<Server port="8005" shutdown="SHUTDOWN">/ ) {
		print FILEOUT "<Server port=\"$shutdownPort\" shutdown=\"SHUTDOWN\">\n";
	} 
	elsif ( $inline =~ /<Resource/ ) {
		print FILEOUT $inline;

		do {
			$inline = <FILEIN>;
			if ( $inline =~ /(.*)maxActive="\d+"(.*)/ ) {
				$inline = "${1}maxActive=\"$connections\"$2\n";
			}
			if ( $inline =~ /(.*)maxIdle="\d+"(.*)/ ) {
				$inline = "${1}maxIdle=\"$maxIdle\"$2\n";
			}
			if ( $inline =~ /(.*)initialSize="\d+"(.*)/ ) {
				$inline = "${1}initialSize=\"$maxIdle\"$2\n";
			}
			if ( $inline =~ /(.*)url=".*"(.*)/ ) {
				$inline = "${1}url=\"$dbUrl\"$2\n";
			}
			if ( $inline =~ /(.*)driverClassName=".*"(.*)/ ) {
				$inline = "${1}driverClassName=\"$driverClassName\"$2\n";
			}
			print FILEOUT $inline;
		} while ( !( $inline =~ /\/>/ ) );
	}
	elsif ( $inline =~ /<Connector/ ) {
		print FILEOUT $inline;
		# suck up the rest of the existing connector definition
		do {
			$inline = <FILEIN>;
		} while ( !( $inline =~ /\/>/ ) );
		print FILEOUT "acceptCount=\"100\"\n";
		print FILEOUT "acceptorThreadCount=\"2\"\n";
		print FILEOUT "connectionTimeout=\"60000\"\n";
		print FILEOUT "asyncTimeout=\"60000\"\n";
		print FILEOUT "disableUploadTimeout=\"false\"\n";
		print FILEOUT "connectionUploadTimeout=\"240000\"\n";
		print FILEOUT "socketBuffer=\"65536\"\n";
		print FILEOUT "executor=\"tomcatThreadPool\"\n";
		print FILEOUT "maxKeepAliveRequests=\"-1\"\n";
		print FILEOUT "keepAliveTimeout=\"-1\"\n";
		print FILEOUT "maxConnections=\"$maxConnections\"\n";
		print FILEOUT "protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n";

		if ( $useTls ) {

			# If using ssl, reconfigure the connector
			# to handle ssl on https port
			# output an ssl connector and a redirect connector
			print FILEOUT "port=\"$httpsPort\"\n";
			print FILEOUT "scheme=\"https\" secure=\"true\" SSLEnabled=\"true\"\n";
			print FILEOUT "keystoreFile=\"/etc/pki/tls/weathervane.jks\" keystorePass=\"weathervane\"\n";
			print FILEOUT "clientAuth=\"false\" sslProtocol=\"TLS\"/>\n";

			# Connector for http traffic
			print FILEOUT "<Connector port=\"$httpPort\"\n";
			print FILEOUT "enableLookups=\"false\" \n";
			print FILEOUT "redirectPort=\"$httpsPort\"/>\n";
			print FILEOUT "acceptCount=\"100\"\n";
			print FILEOUT "acceptorThreadCount=\"2\"\n";
			print FILEOUT "socketBuffer=\"65536\"\n";
			print FILEOUT "connectionTimeout=\"60000\"\n";
			print FILEOUT "disableUploadTimeout=\"false\"\n";
			print FILEOUT "connectionUploadTimeout=\"240000\"\n";
			print FILEOUT "asyncTimeout=\"60000\"\n";
			print FILEOUT "executor=\"tomcatThreadPool\"\n";
			print FILEOUT "maxKeepAliveRequests=\"-1\"\n";
			print FILEOUT "keepAliveTimeout=\"-1\"\n";
			print FILEOUT "maxConnections=\"$maxConnections\"\n";
			print FILEOUT "protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n";
			print FILEOUT "/>\n";
		}
		else {
			print FILEOUT "port=\"$httpPort\"\n";
			print FILEOUT "redirectPort=\"$httpsPort\"/>\n";
		}
	}
	elsif ( $inline =~ /<Executor\s+maxThreads="\d+"(.*)/ ) {
		print FILEOUT "<Executor maxThreads=\"$threads\"${1}\n";
		do {
			$inline = <FILEIN>;
			if ( $inline =~ /(.*)minSpareThreads="\d+"(.*)/ ) {
				my $minThreads = ceil( $threads / 3 );
				$inline = "${1}minSpareThreads=\"$minThreads\"$2\n";
			}

			print FILEOUT $inline;
		} while ( !( $inline =~ /\/>/ ) );
	}
	elsif ( $inline =~ /<Engine.*jvmRoute/ ) {
		print FILEOUT "    <Engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"$hostname\">\n";
	}
	else {
		print FILEOUT $inline;
	}

}
close FILEIN;
close FILEOUT;

# if we are using tls we need to add a security
# constraint to Tomcat's web.xml so all traffic is redirected to ssl
if ($useTls) {
	open( FILEIN,  "/root/apache-tomcat-auction1/conf/web.xml" );
	open( FILEOUT, ">/opt/apache-tomcat-auction1/conf/web.xml" );
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /<\/web-app>/ )
		{
			print FILEOUT "<security-constraint>\n";
			print FILEOUT "<web-resource-collection>\n";
			print FILEOUT "<web-resource-name>Entire Application</web-resource-name>\n";
			print FILEOUT "<url-pattern> /*</url-pattern>\n";
			print FILEOUT "</web-resource-collection>\n";
			print FILEOUT "<user-data-constraint>\n";
			print FILEOUT "<transport-guarantee>CONFIDENTIAL</transport-guarantee>\n";
			print FILEOUT "</user-data-constraint>\n";
			print FILEOUT "</security-constraint>\n";

			print FILEOUT $inline;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
}
