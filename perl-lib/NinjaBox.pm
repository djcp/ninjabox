BEGIN {
    use CGI::Carp qw(carpout);
    open(LOG, ">>/tmp/nb.error.log") or
    die("Unable to open mycgi-log: $!\n");
    carpout(LOG);
}
package NinjaBox;
use strict;
use warnings;
use DBI;
use Filesys::DiskSpace;
use base 'CGI::Application';
use CGI::Carp;
use File::Basename qw/fileparse/;

sub cgiapp_init {
    my $self = shift;
    $self->tmpl_path('../templates/');
    my $app_tmpl = $self->load_tmpl('application.html',
        die_on_bad_params => 0
    );
    $self->param('app_tmpl',$app_tmpl);
    my $dbh = DBI->connect("dbi:SQLite:dbname=../data/ninjabox.db","","",{RaiseError => 1, AutoCommit => 0});
    $self->param('dbh',$dbh);

}

sub teardown {
    my $self = shift;
    my $dbh = $self->param('dbh');
    $dbh->commit();
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

sub check_fs_quota{
    my ($leave_this_percent_free,$total_fs_kb,$used_kb,$content_length_kb) = @_;
    my $percent_free_after_upload = (($total_fs_kb - ($used_kb + $content_length_kb)) / $total_fs_kb) * 100;
    #carp('Percent free after upload: ' . $percent_free_after_upload);
    #carp('Percent to leave free: ' . $leave_this_percent_free);
    if($percent_free_after_upload < $leave_this_percent_free){
        return 0;
    } else {
        # carp('ok for upload');
        return 1;
    }
}

sub upload{
    my $self = shift;
    my $dbh = $self->param('dbh');
    my $q = $self->query();
    my $at = $self->param('app_tmpl');
    my $error = '';
    if($q->request_method() eq 'POST'){
        my ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df($self->param('root_partition'));

        my $total_fs_kb = $avail + $used;
        if(check_fs_quota($self->param('leave_this_percent_free'), $total_fs_kb, $used, $q->http('Content-Length') / 1024)){
            # OK to upload.
            my @fileinfo = fileparse($q->param('file'),qr/\.[^\.]*/);
            my $insert = $dbh->prepare('insert into files(name,file_size,file_path,uploader_nick,source_url,comments,license_id,uploaded_date) values(?,?,?,?,?,?,?,?)');
            #    $insert->execute($q->params('name'), '', $



        } else{
            # Not uploaded.
            $error = 'Not enough space to upload that file. Sorry!';
        }

        $at->param(HTML_TITLE => 'asf',
            OUTPUT => "FS Available: " . ($avail) . 'kb. Content Length: ' . $q->http('Content-Length') / 1024 . 'kb'
        );
        return $at->output();
    } 
    my $form = $self->load_tmpl('upload_form.html', die_on_bad_params => 0);

    my $licenses = $dbh->selectall_arrayref('select * from licenses order by id',{Columns => {}});
    my ($labels,$values);
    foreach my $license(@$licenses){
        push @$values, $license->{'id'};
        $labels->{$license->{'id'}} = $license->{'name'} .' - '.$license->{'license'};
    }

    $form->param(
        FORM_START => $q->start_multipart_form(-method => 'POST') . $q->hidden(-name => 'rm', -value => 'upload'),
        NAME => $q->textfield(-name => 'name', -size => 40),
        FILE => $q->filefield(-name => 'file'),
        NICK => $q->textfield(-name => 'uploader_nick', -size => 30),
        COMMENTS => $q->textarea(-name => 'comments', -rows => 5, -cols => 40),
        SOURCE_URL => $q->textfield(-name => 'source_url', -size => 60),
        LICENSE => $q->popup_menu(-name => 'license_id', -labels => $labels, -values => $values),
        SUBMIT => $q->submit(-value => 'Upload file')
    );
    $at->param(HTML_TITLE => 'Upload a file',
        OUTPUT => $form->output()
    );
    $at->output();
}

sub index{
    my $self = shift;
    my $dbh = $self->param('dbh');
    
    my $at = $self->param('app_tmpl');
    my $tmpl = $self->load_tmpl('index.html', die_on_bad_params => 0);
    my $files = $dbh->selectall_arrayref('select * from files order by popularity, uploaded_date', {Columns => {}});

    $tmpl->param(FILES => $files);
    $at->param(
        'HTML_TITLE' => 'Index',
        'OUTPUT' => $tmpl->output()
    );
    $at->output();
}

1;
