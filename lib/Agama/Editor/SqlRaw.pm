package Agama::Editor::SqlRaw;

use Agama::Model::Dataset;
use Agama::Model::Query;

use Mouse;

sub get_query {
    my ($self, $c) = @_;

    my $dataset_id    = $c->param('dataset_id') + 0;
    my $editor        = $c->param('editor');
    my $sql_statement = $c->param('sql_statement');
    my $query_id      = $c->param('query_id');

    unless ($c->user->can_develop) {
        my $query = Agama::Model::Query->new(id => $query_id)->load;
        $sql_statement = $query->statement;
    }

    my $params = {
        sql_statement  => $sql_statement,
    };

    my $query = Agama::Model::Query->new(
        user      => $c->user,
        dataset   => Agama::Model::Dataset->new(id => $dataset_id)->load,
        editor    => $editor,
        params    => $params,
        statement => $sql_statement,
    );
    
    return $query;
}

sub query_statement {
    my ($self, $query, $args) = @_;

    return $query->params->{sql_statement};
}

1;
