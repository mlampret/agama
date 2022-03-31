package Agama::Controller::Manage::Users;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Users;

sub list {
    my ($self) = @_;

    my $users = Agama::Model::Users->new->get;

    $self->render(
        template => 'manage/users/list',
        users => $users,
    );
}

sub add {
    my ($self) = @_;

    if (!$self->param('email')) {
        $self->stash('add_user_error' => 'Email is missing');
        return $self->list;
    }

    my $user = Agama::Model::User->new(
        first_name => $self->param('first_name'),
        last_name  => $self->param('last_name'),
        email      => $self->param('email'),
    );

    $user->load;

    if ($user->id) {
        $self->stash("add_user_error" => 'User already exists');
        return $self->list;
    };

    $user->save;

    return $self->redirect_to(
        $self->url_for('manage_user', user_id => $user->id)
    );
}

1;
