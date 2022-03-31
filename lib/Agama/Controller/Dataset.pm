package Agama::Controller::Dataset;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Editor::SqlComposer;
use Agama::Editor::SqlRaw;
use Agama::Model::Dataset;
use Agama::Model::Query;

sub query {
    my $self = shift;

    my $dataset_id = $self->param('dataset_id');
    my $dataset = Agama::Model::Dataset->new(id => $dataset_id)->load;

    unless (grep { $_ == $dataset_id } $self->user->allowed_dataset_ids) {
        return $self->redirect_to('home');
    }

    my $query = undef;
    if (my $query_id = $self->param('query_id')) {
        $query = Agama::Model::Query->new(id => $query_id)->load;
    }

    $self->render(
        dataset => $dataset,
        query   => $query,
    );
}

sub exec {
    my $self = shift;

    my $active_tab = $self->param('active_tab');
    my $editor_name = $self->param('editor') || 'sql_composer';
    my $editor_module_name = join '', map { ucfirst } split /_/, $editor_name;
    my $editor_module = "Agama::Editor::$editor_module_name";

    my $editor = $editor_module->new;
    my $query = $editor->get_query($self);

    eval {
        $query->exec->save->load;
    };

    my $exec_error = $@;

    if ($exec_error) {
        my $error_html = $self->render_to_string(
            'query/error',
            error     => $exec_error,
            statement => ($query ? $query->statement : '<no statement>'),
        )->to_string;

        return $self->render(
            json => {
                query       => {},
                query_url   => undef,
                result_html => $error_html,
            },
        );
    }

    my %params = (
        query   => $query,
        options => {
            mode => 'advanced',
            active_tab => $active_tab,
        },
    );

    my $result_html     = $self->render_to_string('query/result', %params)->to_string;
    my $query_url       = $self->url_for('query', query_id => $query->id);
    my $query_hash      = {
        id   => $query->id,
        name => $query->name,
    };

    $self->render(
        json => {
            query       => $query_hash,
            query_url   => $query_url,
            result_html => $result_html,
        },
    );   
}

1;
