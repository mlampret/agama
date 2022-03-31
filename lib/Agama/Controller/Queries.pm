package Agama::Controller::Queries;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;
use Agama::Model::Queries;

sub list {
    my ($self) = @_;

    my $queries = Agama::Model::Queries->new->saved(
        user   => $self->user,
        search => $self->param('search'),
    );

    $self->render(
        queries => $queries,
    );
}

1;
