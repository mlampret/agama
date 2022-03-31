package Agama::Controller::Account;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;
use Agama::Model::Queries;

sub info {
    my ($self) = @_;

    $self->render(
        user => $self->user,
    );
}

1;
