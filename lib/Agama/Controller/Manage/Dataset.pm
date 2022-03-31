package Agama::Controller::Manage::Dataset;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;
use Agama::Model::Roles;

sub show {
    my ($self) = @_;
    
    my $dataset_id = $self->param('dataset_id');

    my $dataset = Agama::Model::Dataset->new(id => $dataset_id)->load;
    my $all_roles = Agama::Model::Roles->new->get;
    
    $self->render(
        dataset   => $dataset,
        all_roles => $all_roles,
    );
}

1;

