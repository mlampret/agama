package Agama::Controller::Manage::Datasets;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;

sub list {
    my ($self) = @_;

    my $datasets = Agama::Model::Datasets->new->get;
    
    $self->render(
        datasets => $datasets,
    );
}

1;

