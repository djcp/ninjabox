#!/usr/bin/perl
use strict;
use warnings;
use lib '../perl-lib';
#use CGI::Carp qw /fatalsToBrowser/;
use NinjaBox;
use CGI::Fast();

while (my $q = new CGI::Fast){
    my $nb = NinjaBox->new(
        QUERY => $q,
        PARAMS => {
            root_partition => '/opt',

            # 20 percent
            leave_this_percent_free => '20'

        }
    );

    $nb->run();
}
