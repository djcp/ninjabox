package NinjaBox;
use strict;
use warnings;
use DBI;
use base 'CGI::Application';

sub cgiapp_init {
    my $self = shift;
    $self->tmpl_path('../templates/');
    my $app_tmpl = $self->load_tmpl('application.html',
        die_on_bad_params => 0
    );
    $self->param('app_tmpl',$app_tmpl);
    my $dbh = DBI->connect("dbi:SQLite:dbname=../data/ninjabox.db","","");

}

sub teardown {
    my $self = shift;
}

sub setup {
    my $self = shift;
    $self->start_mode('index');
    $self->mode_param('rm');
    $self->run_modes(
        'index' => 'index',
        'dmca' => 'dmca',
        'upload' => 'upload'
    );

}

sub index{
    my $self = shift;
    
    my $at = $self->param('app_tmpl');
    $at->param(
        'HTML_TITLE' => 'Index',
        'OUTPUT' => '<h2>Index</h2>'
    );
    $at->output();
}

1;
