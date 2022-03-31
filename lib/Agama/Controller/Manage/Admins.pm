package Agama::Controller::Manage::Admins;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Users;

sub list {
    my ($self) = @_;

    my $users = Agama::Model::Users->new->get;

    $self->render(
        users => $users,
    );
}

1;

