package Agama::Controller::Result;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Datasets;
use Agama::Model::Dataset;
use Agama::Model::Query;

sub csv {
    my $self = shift;

    my $result_id = $self->param('result_id');
    my $result    = Agama::Model::Query::Result->new(id => $result_id)->load;
    my $query     = $result->query;

    unless (grep { $_ == $query->dataset->id } $self->user->allowed_dataset_ids) {
        return $self->redirect_to('home');
    }

    my $fn = 'result_'.$query->id.'_'.$result->id.'.csv';

    $self->app->types->type(csv => 'text/csv');    
    $self->res->headers->content_disposition("attachment;filename=$fn");

    $self->render(
        format => 'csv',
        data   => $result->csv_string,
    );
}

1;
