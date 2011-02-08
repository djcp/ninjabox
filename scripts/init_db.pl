#!/usr/bin/perl
use strict;
use warnings;

use DBI;

my $dbh = DBI->connect("dbi:SQLite:dbname=data/ninjabox.db","","", {RaiseError => 1, AutoCommit => 0});

my @statements = (
    'create table licenses(
        id integer primary key, 
        name text,
        license text, 
        url text
    )',
    'create table files(
        id integer primary key, 
        name text, 
        file_size integer not null default 0,
        file_path text not null,
        content_type text,
        file_extension text,
        uploader_nick text,
        source_url text,
        comments text, 
        license_id integer, 
        uploaded_date integer, 
        popularity integer default 0,

        FOREIGN KEY(license_id) REFERENCES licenses(id)
        )',
    'create index files_file_extensions on files(file_extension)',

    'create table dmca_notices(
        id integer primary key,
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

my @licenses = (
    {
        name => 'unsure',
        license => 'Not really sure.',
        url => ''
    },
    {
        name => 'CC BY',
        license => 'Creative Commons - Attribution',
        url => 'http://creativecommons.org/licenses/by/3.0/'
    },
    {
        name => 'CC BY-SA',
        license => 'Creative Commons - Attribution-ShareAlike',
        url => 'http://creativecommons.org/licenses/by-sa/3.0'
    },
    {
        name => 'CC BY-ND',
        license => 'Creative Commons - Attribution-NoDerivatives',
        url => 'http://creativecommons.org/licenses/by-nd/3.0'
    },
    {
        name => 'CC BY-NC',
        license => 'Creative Commons - Attribution-NonCommercial',
        url => 'http://creativecommons.org/licenses/by-nc/3.0'
    },
    {
        name => 'CC BY-NC-SA',
        license => 'Creative Commons - Attribution-NonCommercial-ShareAlike',
        url => 'http://creativecommons.org/licenses/by-nc-sa/3.0'
    },
    {
        name => 'CC BY-NC-ND',
        license => 'Creative Commons - Attribution-NonCommercial-NoDerivatives',
        url => 'http://creativecommons.org/licenses/by-nc-nd/3.0'
    },
    {
        name => 'GNU FDL',
        license => 'GNU Free Documentation License',
        url => 'http://www.gnu.org/licenses/fdl.html'
    },
    {
        name => 'Public Domain',
        license => 'Public Domain',
        url => ''
    }
);

foreach(@licenses){
    $dbh->do('insert into licenses(name,license,url) values(?,?,?)',{},($_->{name}, $_->{license}, $_->{url}));
}

$dbh->commit;

$dbh->disconnect;


