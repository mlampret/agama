package Agama::Controller::Query;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;
use Agama::Model::Dataset;
use Agama::Model::Query;

sub show {
    my $self = shift;

    my $query_id = $self->param('query_id');
    my $query = Agama::Model::Query->new(id => $query_id)->load;

    unless (grep { $_ == $query->dataset->id } $self->user->allowed_dataset_ids) {
        return $self->redirect_to('home');
    }

    $self->render(
        template => 'dataset/query',
        query    => $query,
    );
}

sub save {
    my $self = shift;

    my $query_id = $self->param('query_id');
    my $query    = Agama::Model::Query->new(id => $query_id)->load;
    my $name     = $self->param('name');
    
    # TODO: check there is no query with the same name
    # or maybe do that in the model

    $name =~ s/(^\s+|\s$)//g;

    unless (grep { $_ == $query->dataset->id } $self->user->allowed_dataset_ids) {
        return $self->render(
            status => 401,
            json   => {},
        );
    }

    $query->name($name);
    $query->update_name;

    $self->render(json => {});
}

sub remove {
    my $self = shift;

    my $query_id = $self->param('query_id');
    my $query    = Agama::Model::Query->new(id => $query_id)->load;

    unless (grep { $_ == $query->dataset->id } $self->user->allowed_dataset_ids) {
        return $self->render(
            status => 401,
            json   => {},
        );
    }

    $query->name(undef);
    $query->update_name;

    $self->render(json => {});
}

1;
