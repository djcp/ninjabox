#!/usr/bin/perl
use strict;
use warnings;
use lib '../perl-lib';
use CGI::Carp qw /fatalsToBrowser/;
use NinjaBox;

my $nb = NinjaBox->new(
    PARAMS => {
        root_partition => '/opt',

        # 20 percent
        leave_this_percent_free => '20'
        
    }
);

$nb->run();
