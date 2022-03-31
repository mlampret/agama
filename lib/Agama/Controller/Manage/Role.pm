package Agama::Controller::Manage::Role;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Dataset;
use Agama::Model::Role;
use Agama::Model::User;

sub show {
    my ($self) = @_;

    my $role_id = $self->param('role_id');

    my $role = Agama::Model::Role->new(id => $role_id)->load;
    
    my $all_datasets = Agama::Model::Datasets->new->get;;
    my $all_users = Agama::Model::Users->new->get;;
    
    $self->render(
        role => $role,
        all_datasets => $all_datasets,
        all_users => $all_users,
    );
}

sub _user {
    my ($self, $action) = @_;

    my $role_id = $self->param('role_id');
    my $user_id = $self->param('user_id');

    my $role = Agama::Model::Role->new(id => $role_id)->load;
    my $user = Agama::Model::User->new(id => $user_id)->load;
    
    $role->$action($user);
    
    my $datasets_html = $self->render_to_string(
        'manage/user/datasets',
        user => $user,
    )->to_string;

    $self->render(json => {
        status => 'ok',
        datasets_html => $datasets_html
    });
}

sub _dataset {
    my ($self, $action) = @_;

    my $role_id    = $self->param('role_id');
    my $dataset_id = $self->param('dataset_id');

    my $role    = Agama::Model::Role->new(id => $role_id)->load;
    my $dataset = Agama::Model::Dataset->new(id => $dataset_id)->load;

    $role->$action($dataset);
    
    my $users_html = $self->render_to_string(
        'manage/dataset/users',
        dataset => $dataset,
    )->to_string;

    $self->render(json => {
        status => 'ok',
        users_html => $users_html,
    });
}

sub add_user       { shift->_user('add_user') }
sub remove_user    { shift->_user('remove_user') }
sub add_dataset    { shift->_dataset('add_dataset') }
sub remove_dataset { shift->_dataset('remove_dataset') }

sub delete {
    my ($self) = @_;

    my $role_id = $self->param('role_id');

    Agama::Model::Role->new(id => $role_id)->load->delete;

    $self->redirect_to(
        $self->url_for('manage_roles')
    );
}

1;

