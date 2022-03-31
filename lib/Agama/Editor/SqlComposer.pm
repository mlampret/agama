package Agama::Editor::SqlComposer;

use Agama::Model::Dataset;
use Agama::Model::Query;

use List::MoreUtils qw/ uniq /;
use Mouse;

sub get_query {
    my ($self, $c) = @_;

    my $dataset_id  = $c->param('dataset_id');
    my $topic_id    = $c->param('topic_id');
    my $grouping_id = $c->param('grouping_id');

    # Todo: Move to controller
    # unless (grep { $_ == $dataset_id } $self->user->allowed_dataset_ids) {
    #    return $self->redirect_to('home');
    # }

    my @filters;
    my @groupings;

    for my $i (1..500) {
        # filters
        my $prefix = "filter_$i";
        my $filter_id = $c->param("${prefix}_id");
        my $operator = $c->param("${prefix}_operator");
        if ($filter_id) {
            my $filter_param_1 = $c->param("${prefix}_param_1");
            my $filter_param_2 = $c->param("${prefix}_param_2");
            my $filter = Agama::Model::Dataset::Filter->new(id => $filter_id)->load;
            $filter->operator($operator) if $operator;
            $filter->params([ grep { defined } ($filter_param_1, $filter_param_2) ]);
            push @filters, $filter;
        }

        # groupings
        my $grouping_id = $c->param("grouping_${i}_id");
        if ($grouping_id) {
            my $grouping = Agama::Model::Dataset::Grouping->new(id => $grouping_id)->load;
            push @groupings, $grouping;
        }
    }

    my $params = {
        topic     => { id => $topic_id },
        filters   => [ map { $_->as_hash } @filters ],
        groupings => [ map { $_->as_hash } @groupings ],
    };

    my $query = Agama::Model::Query->new(
        user      => $c->user,
        dataset   => Agama::Model::Dataset->new(id => $dataset_id)->load,
        topic     => Agama::Model::Dataset::Topic->new(id => $topic_id)->load,
        filters   => \@filters,
        groupings => \@groupings,
        editor    => 'sql_composer',
        params    => $params,
    );

    return $query;
}

sub query_statement {
    my ($self, $query, %args) = @_;

    # Topic, grouping - load them here if missing
    
    # we support only 2 groupings
    # grouping1 = groups on y axis
    # grouping2 = groups on x axis

    my $grouping1 = $query->groupings->[0];
    my $grouping2 = $query->groupings->[1];

    my $statement = '';
    $statement .= 'SELECT ';
    $statement .= $grouping1->select.', ' if $grouping1 && $grouping1->select && !$query->dataset->group_by;
    $statement .= $grouping2->select.', ' if $grouping2 && $grouping2->select && !$query->dataset->group_by;
    $statement .= $query->dataset->group_by ? $query->dataset->select : $query->topic->select;
    $statement .= "\nFROM ";
    $statement .= $query->dataset->from;
    if ($args{force_index} && $query->explain->[0]->{possible_keys}) {
        my ($index) = split /,/, $query->explain->[0]->{possible_keys};
        $statement .= "\nFORCE INDEX ($index)";
        $query->index_forced(1);
    }

    my @joins = ();
    push (@joins, $_->join) for ($query->filters->@*);
    push @joins, $grouping1->join if $grouping1 && $grouping1->join;
    push @joins, $grouping2->join if $grouping2 && $grouping2->join;

    for my $join (uniq @joins) {
        $statement .= "\n" . $join;
    }

    $statement .= "\nWHERE 1";
    $statement .= $self->_query_where($query);

    my @group_by = ();

    push @group_by, $grouping1->group_by if $grouping1 && !$query->dataset->group_by;
    push @group_by, $grouping2->group_by if $grouping2 && !$query->dataset->group_by;

    if ($query->topic->group_by) {
        push @group_by, $query->topic->group_by;
    }
    elsif ($query->dataset->group_by) {
        push @group_by, $query->dataset->group_by;
    }

    if (scalar(@group_by)) {
        $statement .= "\nGROUP BY ".join(', ',@group_by);
    }
    
    if ($query->dataset->group_by) {
        $statement =
            "SELECT "
            . ($grouping1 && $grouping1->select ? $grouping1->select.', ' : "")
            . ($grouping2 && $grouping2->select ? $grouping2->select.', ' : "")
            . $query->topic->select
            . "\nFROM ("
            . "\n\t".join("\n\t", split /\n/, $statement)
            . "\n) t"
            . ($grouping1
                ? "\nGROUP BY ".$grouping1->group_by.($grouping2 ? ', '.$grouping2->group_by : '')
                : ""
            );
    }
    else {
        # order by
        $query->topic->order_by
            ? $query->order_by($query->topic->order_by)
            : $query->order_by(join ', ', @group_by, 1);

        $statement .= "\nORDER BY ".$query->order_by;
    }

    # variables
    $statement =~ s/\$where/"WHERE 1 ".$self->_query_where($query)/ge;

    # limit
    $statement .= "\nLIMIT 1000";

    # cleanup
    $statement =~ s/\n+/\n/g;
    $statement =~ s/WHERE 1\s+AND/WHERE/smg;
    $statement =~ s/WHERE 1\n//smg;
    $statement =~ s/(ORDER BY .+), 1\n/$1\n/smg;
    $statement =~ s/\nORDER BY 1//smg;

    return $statement;
}

sub _query_where {
    my ($self, $query) = @_;

    my @where;

    for my $filter ($query->filters->@*) {
        next unless $filter->where;
        push @where, $filter->where_with_params;
    }

    my $where_str = join '', map { "\n\tAND $_" }  @where;

    return $where_str || '';
}

1;
