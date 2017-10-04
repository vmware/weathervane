#!/usr/bin/perl
# This script is used to add the weathervane domain to
# The search line of /etc/resolv.conf
open( FILEIN, "/etc/resolv.conf" )
  or die "Can't open file /etc/resolv.conf: $!";

my $foundSearch = 0;
my $searchLine ;
while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /^search/ ) {
		chomp($inline);
		$searchLine = $inline;
		$foundSearch = 1;
	}
}

if (!$foundSearch) {
	`echo  "search weathervane\n" >> /etc/resolv.conf`;
} else {
	`echo  "$searchLine weathervane\n" >> /etc/resolv.conf`;
}



 