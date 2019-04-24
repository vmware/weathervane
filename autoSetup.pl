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
#
# Created by: Hal Rosenberg
#
# This script sets up Weathervane on Centos7
#
package AutoSetup;
use strict;

# Turn on auto flushing of output
BEGIN { $| = 1 }

sub runAndLog {
	my ( $fileout, $cmd ) = @_;
	print $fileout "COMMAND> $cmd\n";
	open( CMD, "$cmd 2>&1 |" ) || die "Couldn't run command $cmd: $!\n";
	while ( my $line = <CMD> ) {
		print $fileout $line;
	}
	close CMD;
}

sub setOS {

	if ( -e "/etc/centos-release" ) {
		my $release = `cat /etc/centos-release`;
		if ( $release =~ /release 7/ ) {
			return "centos7";
		}
		else {
			die "The only distribution currently supported by this script is Centos 7/\n";
		}
	}
	else {
		die "The only distribution currently supported by this script is Centos 7/\n";
	}
}

sub setServiceManager {
	my ($os) = @_;

	if ( $os eq "centos6" ) {
		return "init";
	}
	elsif ( $os eq "centos7" ) {
		return "systemd";
	}
	else {
		die "Unsupported OS $os\n";
	}
}

sub forceLicenseAccept {
	open( my $fileout, "/root/weathervane/Notice.txt" ) or die "Can't open file /root/weathervane/Notice.txt: $!\n";
	while (my $inline = <$fileout>) {
		print $inline;
	}
	
	print "Do you accept these terms and conditions (yes/no)? ";
	my $answer = <STDIN>;
	chomp($answer);
	$answer = lc($answer);
	while (($answer ne "yes") && ($answer ne "no")) {
		print "Please answer yes or no: ";
		$answer = <STDIN>;
		chomp($answer);
		$answer = lc($answer);
	}
	if ($answer eq "yes") {
		open (my $file, ">/root/weathervane/.accept-autosetup") or die "Can't create file .accept-autosetup: $!\n";
		close $file;
	} else {
		exit -1;		
	}
}

unless (-e "/root/weathervane/.accept-autosetup") {
	forceLicenseAccept();
}

my $cmdout;
my $fileout;
open( $fileout, ">autoSetup.log" ) or die "Can't open file autoSetup.log for writing: $!\n";

my $os             = setOS();

my $serviceManager = setServiceManager($os);

print "Performing autoSetup for a $os host.\n";
print $fileout "Performing autoSetup for a $os host.\n";
runAndLog( $fileout, "setenforce 0" );

print "Building Weathervane executables\n";
runAndLog( $fileout, "./gradlew clean release" );

runAndLog( $fileout, "yum install -y wget" );
runAndLog( $fileout, "yum install -y curl" );
runAndLog( $fileout, "yum install -y lynx" );

print "Setting up various configuration files.  See autoSetup.log for details\n";
print $fileout "Setting up various configuration files.  See autoSetup.log for details\n";
runAndLog( $fileout, "cp configFiles/host/$os/sysctl.conf /etc/" );
runAndLog( $fileout, "cp configFiles/host/$os/config /etc/selinux/" );
runAndLog( $fileout, "cp configFiles/host/$os/login /etc/pam.d/login" );
runAndLog( $fileout, "cp configFiles/host/$os/limits.conf /etc/security/limits.conf" );
runAndLog( $fileout, "cp configFiles/host/$os/bashrc /root/.bashrc" );

print "Installing Perl Modules\n";
print $fileout "Installing Perl Modules\n";
runAndLog( $fileout, "yum install -y perl-App-cpanminus" );
runAndLog( $fileout, "cpanm YAML" );
runAndLog( $fileout, "cpanm Config::Simple" );
runAndLog( $fileout, "cpanm String::Util" );
runAndLog( $fileout, "cpanm Statistics::Descriptive" );
runAndLog( $fileout, "cpanm Moose" );
runAndLog( $fileout, "service network restart" );
runAndLog( $fileout, "cpanm MooseX::Storage" );
runAndLog( $fileout, "cpanm Tie::IxHash" );
runAndLog( $fileout, "cpanm MooseX::ClassAttribute" );
runAndLog( $fileout, "cpanm MooseX::Types" );
runAndLog( $fileout, "cpanm JSON" );
runAndLog( $fileout, "cpanm Switch" );
runAndLog( $fileout, "cpanm Log::Log4perl" );
runAndLog( $fileout, "cpanm Log::Dispatch::File" );
runAndLog( $fileout, "cpanm LWP" );
runAndLog( $fileout, "service network restart" );

close $fileout;

print "AutoSetup Complete.\n";
print "You still need to perform the following steps:\n";
print "    - Reboot this VM.\n";
print "    - Disable the sceensaver if you are running with a desktop manager.\n";
print "    - Before cloning this VM, edit the file /etc/resolv.conf so\n";
print "      that the IP address on the nameserver line is that of your primary driver.\n";
print "    - Clone this VM as appropriate for your deployment\n";
print "    - On the primary driver, edit the Weathervane configuration file as needed.\n";

1;
