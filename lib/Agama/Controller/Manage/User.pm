package Agama::Controller::Manage::User;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Users;
use Agama::Model::Roles;

sub show {
    my ($self) = @_;
    
    my $user_id = $self->param('user_id');

    my $user = Agama::Model::User->new(id => $user_id)->load;
    my $all_roles = Agama::Model::Roles->new->get;

    $self->render(
        user      => $user,
        all_roles => $all_roles,
    );
}

sub update {
    my ($self) = @_;

    my $user_id = $self->param('user_id');

    my $user = Agama::Model::User->new(id => $user_id)->load;

    $user->status( $self->param('status') );
    $user->type( $self->param('type') );

    $user->save;

    $self->redirect_to(
        $self->url_for('manage_user', user_id => $user->id)
    );
}

1;

