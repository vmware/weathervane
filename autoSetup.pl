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

my $cmdout;
my $fileout;
open( $fileout, ">autoSetup.log" ) or die "Can't open file autoSetup.log for writing: $!\n";

print "Installing Perl Modules\n";
print $fileout "Installing Perl Modules\n";
runAndLog( $fileout, "yum install -y perl-App-cpanminus" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org YAML" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Config::Simple" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org String::Util" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Statistics::Descriptive" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Moose" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org MooseX::Storage" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Tie::IxHash" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org MooseX::ClassAttribute" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org MooseX::Types" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org JSON" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Switch" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Log::Log4perl" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org Log::Dispatch::File" );
runAndLog( $fileout, "cpanm -n --mirror http://cpan.cpantesters.org LWP" );

close $fileout;

print "AutoSetup Complete.\n";

1;
