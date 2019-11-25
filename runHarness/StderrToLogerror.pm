# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package StderrToLogerror;
 
use Log::Log4perl qw(get_logger :levels);

sub TIEHANDLE {
   my($class, %options) = @_;

   my $self = {
       level    => $ERROR,
       category => '',
       %options
   };
 
   $self->{logger} = get_logger($self->{category}),
   bless $self, $class;
}
 
sub PRINT {
    my($self, @rest) = @_;
    $Log::Log4perl::caller_depth++;
    $self->{logger}->log($self->{level}, "StderrToLogerror:", @rest);
    $Log::Log4perl::caller_depth--;
}
 
1;
