#!/usr/bin/perl
use strict;
use warnings;

use DBI;

my $dbh = DBI->connect("dbi:SQLite:dbname=data/ninjabox.db","","", {RaiseError => 1, AutoCommit => 0});

my @statements = (
    'create table licenses(
        id serial not null, 
        license text, 
        url text
    )',
    'create table files(
        id serial not null, 
        name text, 
        mime_type text, 
        file_size integer not null default 0,
        file_path text not null,
        uploader_nick text,
        source_url text,
        comments text, 
        license_id integer, 
        uploaded_date integer, 
        popularity integer,

        FOREIGN KEY(license_id) REFERENCES licenses(id)
    )',
    'create table dmca_notices(
        id serial not null,
        file_id integer,
        reason text,
        phone text,
        email text,
        name text,

        FOREIGN KEY(file_id) REFERENCES files(id)
    )'
);

foreach(@statements){
    $dbh->do($_);
}

$dbh->commit;

$dbh->disconnect;

