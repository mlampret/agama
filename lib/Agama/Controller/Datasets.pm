package Agama::Controller::Datasets;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;

sub list {
    my ($self) = @_;

    my $datasets = Agama::Model::Datasets->new->get(user => $self->user);

    $self->render(
        datasets => $datasets,
    );
}

1;
