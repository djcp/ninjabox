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
    my $dbh = DBI->connect("dbi:SQLite:dbname=../data/ninjabox.db","","",{RaiseError => 1, AutoCommit => 0});
    $self->param('dbh',$dbh);
}

sub init_app_template{
    my $self=shift;
    my $app_tmpl = $self->load_tmpl('application.html',
        die_on_bad_params => 0
    );
    $self->init_filespace_counting();
    my $used = $self->param('used');
    my $total_fs_kb = $self->param('total_fs_kb');
    $app_tmpl->param(
        'FREE_SPACE_MB' => sprintf('%.2f',$used / 1024),
        'TOTAL_SPACE_MB' => sprintf('%.2f',$total_fs_kb / 1024),
        'FREE_SPACE_GB' => sprintf('%.2f',$used / 1024 / 1024),
        'TOTAL_SPACE_GB' => sprintf('%.2f',$total_fs_kb / 1024 / 1024),
        'PERCENT_FREE' => sprintf('%.2f',(($total_fs_kb - $used) / $total_fs_kb) * 100),
        'PERCENT_USED' => 100 - sprintf('%.2f',(($total_fs_kb - $used) / $total_fs_kb) * 100),
        'ROOT_URL' => $self->query()->url
    );
    return $app_tmpl;
}

sub init_filespace_counting{
    my $self = shift;
    my ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df($self->param('root_partition'));
    $self->param('total_fs_kb', $avail + $used);
    $self->param('used', $used);
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
        'upload' => 'upload',
        'click' => 'click',
        'dmca_list' => 'dmca_list'
    );
}

sub dmca_list{
    my $self = shift;
    my $dbh = $self->param('dbh');
    my $at = $self->init_app_template();

    my $tmpl = $self->load_tmpl('dmca_list.html', die_on_bad_params => 0);

    $tmpl->param(
        DMCA_LIST => ($dbh->selectall_arrayref('
                select dmca_notices.*, files.name as file_name, files.file_path 
                from dmca_notices,files 
                where dmca_notices.file_id = files.id 
                order by dmca_notices.id',{Columns => {}}) || [])
    );

    $at->param(
        HTML_TITLE => 'DMCA Takedown notices',
        OUTPUT => $tmpl->output()
    );
    $at->output();
}

sub dmca{
    my $self = shift;
    my $q = $self->query();
    my $dbh = $self->param('dbh');
    my $error = '';
    if(
        $q->request_method() eq 'POST' 
        && $q->param('file_id') 
        && $q->param('reason') 
        && $self->check_email($q->param('email'))
    ){
        $dbh->do('insert into dmca_notices(file_id,reason,phone,email,name) values(?,?,?,?,?)',{},
            ($q->param('file_id'), $q->param('reason'), $q->param('phone') || '', $q->param('email') || '', $q->param('name') || '' )
        );
        $self->header_type('redirect');
        $self->header_props(-url => $q->url(-absolute => 1));
        return;
    }
    my $at = $self->init_app_template();
    my $form = $self->load_tmpl('dmca.html', die_on_bad_params => 0);
    my $files = $dbh->selectall_arrayref('select * from files order by file_path', {Columns => {}});
    my ($labels, $values);
    foreach my $file(@$files){
        push @$values, $file->{'id'};
        $labels->{$file->{'id'}} = $file->{'name'} .' - '.$file->{'file_path'};
    }

    $form->param(
        FORM_START => $q->start_form(-method => 'POST') . $q->hidden(-name => 'rm', -value => 'dmca'),
        FILE_ID => $q->popup_menu(-name => 'file_id', -labels => $labels, -values => $values),
        REASON => $q->textarea(-name => 'reason', -rows => 5, -cols => 40), 
        PHONE => $q->textfield(-name => 'phone', -size => 20),
        EMAIL => $q->textfield(-name => 'email', -size => 30),
        NAME => $q->textfield(-name => 'name', -size => 25),
        SUBMIT => $q->submit(-value => 'Submit DMCA Notice')
    );

    $at->param(HTML_TITLE => 'Submit a DMCA takedown notice',
        OUTPUT => $form->output()
    );
    $at->output();
}

sub check_email{
    my ($self,$email) = @_;
    return 0 unless($email);
    if($email =~ m/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i){
        return 1;
    } else {
        return 0;
    }
}

sub click{
    my $self = shift;
    my $q = $self->query();
    if($q->request_method() eq 'POST'){
        my $dbh = $self->param('dbh');
        my $file_id = $q->param('id');
        if($file_id){
            $dbh->do('update files set popularity = popularity + 1 where id = ?', {}, ($file_id));
        }
        $self->header_props(-status => '200 OK');
    }
    return;
}

sub check_fs_quota{
    my ($leave_this_percent_free,$total_fs_kb,$used_kb,$content_length_kb) = @_;
    my $percent_free_after_upload = (($total_fs_kb - ($used_kb + $content_length_kb)) / $total_fs_kb) * 100;
    if($percent_free_after_upload < $leave_this_percent_free){
        return 0;
    } else {
        return 1;
    }
}

sub upload{
    my $self = shift;
    my $dbh = $self->param('dbh');
    my $q = $self->query();
    my $at = $self->init_app_template();
    my $error = '';
    if( 
        $q->request_method() eq 'POST' 
        && $q->param('file') 
    ){
        if(check_fs_quota($self->param('leave_this_percent_free'), $self->param('total_fs_kb'), $self->param('used'), $q->http('Content-Length') / 1024)){
            # OK to upload.
            my @fileinfo = fileparse($q->param('file'),qr/\.[^\.]*/);
            my $insert = $dbh->prepare('insert into files(name,file_size,file_path,uploader_nick,source_url,comments,license_id,uploaded_date,content_type,file_extension) values(?,?,?,?,?,?,?,?,?,?)');
            my $name = $fileinfo[0];
            $name =~ s/[^a-z\d\- ]//gis;
            my $file_path = 'files/'. $name . '-' . time() . $fileinfo[2];
            my $fh = $q->upload('file');
            open(OUTPUT,'>',$file_path) or croak($!);
            while(<$fh>){
                print OUTPUT $_;
            }
            close OUTPUT;
            my $file_size = -s $file_path;
            $insert->execute($q->param('name') || '', $file_size || '', $file_path || '', $q->param('uploader_nick') || '', $q->param('source_url') || '', $q->param('comments') || '', $q->param('license_id') || '', time(),$q->uploadInfo($q->param('file'))->{'Content-Type'} || '', $fileinfo[2] );
            $insert->finish();
            $self->header_type('redirect');
            $self->header_props(-url => $q->url(-absolute => 1));
            return;
        } else{
            # Not uploaded.
            $error = 'Not enough space to upload that file. Sorry!';
        }
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
    
    my $at = $self->init_app_template();
    my $tmpl = $self->load_tmpl('index.html', die_on_bad_params => 0);
    my $files = $dbh->selectall_arrayref('select * from files order by popularity, uploaded_date', {Columns => {}});

    for(@$files){
        $_->{FILE_SIZE_IN_MB} = sprintf('%.2f',$_->{file_size} / 1024 / 1024);
    }

    $tmpl->param(FILES => $files);
    $at->param(
        'HTML_TITLE' => 'Index',
        'OUTPUT' => $tmpl->output()
    );
    $at->output();
}

1;
