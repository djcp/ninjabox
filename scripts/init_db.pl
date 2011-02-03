#!/usr/bin/perl
use strict;
use warnings;

use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=../data/ninjabox.db","","");

$dbh->do('create table foobar(id serial, name character varying)');

$dbh->disconnect();

