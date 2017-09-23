#!/usr/bin/perl

use strict;
use POSIX;

my $mongodPort  = $ENV{'MONGODPORT'};
my $numShards   = $ENV{'NUMSHARDS'};
my $numReplicas = $ENV{'NUMREPLICAS'};
my $isCfgSvr    = $ENV{'ISCFGSVR'};
my $isMongos    = $ENV{'ISMONGOS'};

print "configure mongo.  numShards = $numShards, numReplicas = $numReplicas, isCfgSvr = $isCfgSvr, isMongos = $isMongos\n";
if ( ( $numShards > 0 ) && ( $numReplicas > 0 ) ) {
	if ($isCfgSvr) {
		configureConfigSvr();
	}
	elsif ($isMongos) {
		configureMongos();
	}
	else {
		configureShardedReplicatedMongodb();
	}
}
elsif ( $numShards > 0 ) {
	if ($isCfgSvr) {
		configureConfigSvr();
	}
	elsif ($isMongos) {
		configureMongos();
	}
	else {
		configureShardedMongodb();
	}
}
elsif ( $numReplicas > 0 ) {
	configureReplicatedMongodb();
}
else {
	configureSingleMongodb();
}

sub configureSingleMongodb {
	print "Configure Single MongoDB\n";
	open( FILEIN, "/root/mongod-unsharded.conf" )
	  or die "Error opening /etc/mongod-unsharded.conf:$!";
	open( FILEOUT, ">/etc/mongod.conf" )
	  or die "Error opening /etc/mongod.conf:$!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /port:/ ) {
			print FILEOUT "    port: " . $mongodPort . "\n";
		}
		elsif ( $inline =~ /fork/ ) {
			next;
		}
		elsif ( $inline =~ /path/ ) {
			next;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;

}

sub configureShardedMongodb {

	print "Configure Sharded MongoDB\n";
	open( FILEIN, "/root/mongod-sharded.conf" )
	  or die "Error opening /etc/mongod-sharded.conf:$!";
	open( FILEOUT, ">/etc/mongod.conf" )
	  or die "Error opening /etc/mongod.conf:$!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /port:/ ) {
			print FILEOUT "    port: " . $mongodPort . "\n";
		}
		elsif ( $inline =~ /fork/ ) {
			next;
		}
		elsif ( $inline =~ /path/ ) {
			next;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;

}

sub configureConfigSvr {
	my $mongocPort  = $ENV{'MONGOCPORT'};
	my $cfgSvrNum   = $ENV{'CFGSVRNUM'};
	print "Configure MongoDB Config Server.  port = $mongocPort, cfgSvrNum = $cfgSvrNum\n";

	open( FILEIN, "/root/mongoc$cfgSvrNum.conf" )
	  or die "Error opening /etc/mongoc$cfgSvrNum.conf:$!";
	open( FILEOUT, ">/tmp/mongoc$cfgSvrNum.conf" )
	  or die "Error opening /tmp/mongoc$cfgSvrNum.conf:$!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /port:/ ) {
			print FILEOUT "    port: " . $mongocPort . "\n";
		}
		elsif ( $inline =~ /fork/ ) {
			next;
		}
		elsif ( $inline =~ /path/ ) {
			next;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;

	`mv /tmp/mongoc$cfgSvrNum.conf /etc/mongoc$cfgSvrNum.conf`;
}

sub configureMongos {
	my $mongosPort  = $ENV{'MONGOSPORT'};
	print "Configure mongod.  port = $mongosPort\n";
	
	open( FILEIN,  "/root/mongos.conf" );
	open( FILEOUT, ">/tmp/mongos.conf" );
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /port:/ ) {
			print FILEOUT "    port: " . $mongosPort . "\n";
		}
		elsif ( $inline =~ /fork/ ) {
			next;
		}
		elsif ( $inline =~ /path/ ) {
			next;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
	`mv /tmp/mongos.conf /etc/mongos.conf`;
}

sub configureReplicatedMongodb {
	print "Configure Replicated MongoDB\n";

	open( FILEIN, "/root/mongod-replica.conf" )
	  or die "Error opening /etc/mongod-replica.conf:$!";
	open( FILEOUT, ">/etc/mongod.conf" )
	  or die "Error opening /etc/mongod.conf:$!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /port:/ ) {
			print FILEOUT "    port: " . $mongodPort . "\n";
		}
		elsif ( $inline =~ /path/ ) {
			next;

		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
}

sub configureShardedReplicatedMongodb {
	print("Dockerized sharded and replicated MongoDB is not yet implemented.");
	exit(-1);
}
