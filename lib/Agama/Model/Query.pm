package Agama::Model::Query;

use Agama::Model::Dataset;
use Agama::Model::Dataset::Filter;
use Agama::Model::Dataset::Grouping;
use Agama::Model::Dataset::Topic;
use Agama::Model::Query::Result;
use Agama::Model::User;

use utf8;
use Digest::MD5 qw/md5_hex/;
use JSON;
use List::MoreUtils qw/ uniq /;
use Time::HiRes qw/ time /;
use Mouse;

with 'Agama::Role::DB';

has id             => (is => 'rw', isa => 'Int');
has md5            => (is => 'rw');
has name           => (is => 'rw');
has saved          => (is => 'rw', isa => 'Int');
has statement      => (is => 'rw', lazy_build => 1);
has params         => (is => 'rw');
has results        => (is => 'rw', lazy_build => 1);
has user           => (is => 'rw');
has dataset        => (is => 'rw');
has editor         => (is => 'rw', isa => 'Str');
has topic          => (is => 'rw');
has filters        => (is => 'rw', default => sub { [] });
has groupings      => (is => 'rw', default => sub { [] });
has order_by       => (is => 'rw');
has explain        => (is => 'rw', lazy_build => 1);
has index_forced   => (is => 'rw', default => 0);
has date_last_exec => (is => 'rw');

sub _build_explain {
    my ($self) = @_;

    return unless $self->statement;

    my $rows;

    # EXPLAIN doesn't work with all statements, e.g. SHOW
    eval {
        $rows = $self->dbh_ds($self->dataset->database)->selectall_arrayref(
            "EXPLAIN ".$self->statement,
            {Slice => {}},
        );

        for my $row (@$rows) {
            $row->{possible_keys} =~ s/,/, /g
                if $row->{possible_keys};
        }
    };

    return $rows;
}

sub _build_results {
    my ($self) = @_;

    my $rows = $self->dbh->selectall_arrayref(
        "SELECT * FROM result WHERE query_id = ? ORDER BY date_created",
        {Slice => {}},
        $self->id,
    );

    my @results = ();

    for my $row (@$rows) {
        push @results, $self->_result_rw_to_result_obj($row);
    }

    return \@results;
}

sub _build_statement {
    my ($self, %args) = @_;

    my $editor_module_name = join '', map { ucfirst } split /_/, $self->editor;
    my $editor_module = "Agama::Editor::$editor_module_name";
    my $editor = $editor_module->new;

    my $statement = $editor->query_statement($self, %args);

    $self->statement($statement);

    my $explain = $self->explain;

    # force index if necessary
    if ($statement !~ m/JOIN/i && $explain->[0]->{possible_keys} && ! $explain->[0]->{key} && ! $self->index_forced) {
        $self->index_forced(1);
        $self->_build_statement(force_index => 1);
        $self->explain( $self->_build_explain );
    }

    return $statement;
}

sub _result_rw_to_result_obj {
    my ($self, $row) = @_;

    my $matrix = ($row->{matrix} ? from_json($row->{matrix}) : []);
    my $group_count = $self->group_count($matrix);

    my $result = Agama::Model::Query::Result->new(
        id => $row->{id},
        query => $self,
        user => Agama::Model::User->new(id => $row->{user_id})->load,
        matrix => $matrix,
        group_count => $group_count // 0,
        statement => $row->{statement},
        exec_time => $row->{exec_time},
        date_created => $row->{date_created},
    );

    return $result;
}

sub last_result {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM result WHERE query_id = ? ORDER BY date_created DESC LIMIT 1",
        undef,
        $self->id,
    );

    return $self->_result_rw_to_result_obj($row);
}

sub exec {
    my ($self, %args) = @_;

    my $start_time = time;

    my $sth = $self->dbh_ds($self->dataset->database)->prepare("-- AGAMA QUERY --\n".$self->statement);
    $sth->execute();
    my $rows = $sth->fetchall_arrayref({});

    my $exec_time = time - $start_time;

    my @cols = $sth->{NAME}->@*;

    # convert hashes to arrays
    my $rows_a = [];
    for my $row (@$rows) {
        push @$rows_a, [ map { $row->{$_} } @cols ];
    }

    my $result = Agama::Model::Query::Result->new(
        raw_columns => $sth->{NAME},
        raw_rows    => $rows,
        statement   => $self->statement,
        group_count => $self->group_count($rows_a),
        exec_time   => $exec_time,
    );

    # $self->results->@* loads all results
    # $self->results([ $self->results->@*, $result ]);
    # to avoid that, this should be fine for now
    $self->results([ $result ]);

    return $self;
}

sub group_count {
    my ($self, $matrix) = @_;
    my $gc = scalar($self->groupings->@*);    

    unless ($gc) {
        my $one_grouping = 1;
        for my $row (@$matrix[1..scalar(@$matrix)-1]) {
            if (scalar @$row != 2) {
                $one_grouping = 0;
                last;
            }
            unless ($row->[1] =~ m/^[\d\.]+$/) {
                $one_grouping = 0;
            }
        }
        $gc = 1 if $one_grouping && $self->statement =~ m/group\s+by/i;
    }

    return $gc;
}

sub generate_md5 {
    my ($self) = @_;

    my $json = JSON->new->canonical(1);

    return md5_hex($json->encode({
        dataset_id => $self->dataset->id + 0, # + 0 to force number
        params     => $self->params,
    }));
}

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM query WHERE id = ?",
        {Slice => {}},
        $self->id,
    );

    $self->md5($row->{md5});
    $self->name($row->{name});

    $self->dataset(Agama::Model::Dataset->new(id => $row->{dataset_id})->load);
    $self->topic(Agama::Model::Dataset::Topic->new(id => $row->{topic_id})->load)
        if $row->{topic_id};

    if ($row->{filters}) {
        my @filters = ();

        my $filters_ar = $row->{filters}
            ? from_json($row->{filters})
            : [];

        for my $filter_hr (@$filters_ar) {
            my $filter = Agama::Model::Dataset::Filter->new(id => $filter_hr->{id})->load;
            $filter->params($filter_hr->{params}) if $filter_hr->{params};
            $filter->operator($filter_hr->{operator}) if $filter_hr->{operator};
            push @filters, $filter;
        }
        $self->filters(\@filters);
    }

    if ($row->{groupings}) {
        my @groupings = ();
        my $groupings_ar = $row->{groupings}
            ? from_json($row->{groupings})
            : [];

        for my $grouping_hr (@$groupings_ar) {
            push @groupings, Agama::Model::Dataset::Grouping->new(id => $grouping_hr->{id})->load;
        }

        $self->groupings(\@groupings);
    }

    $self->statement($row->{statement}) if $row->{statement};
    $self->editor($row->{editor}) if $row->{editor};
    $self->params(from_json $row->{params}) if $row->{params};

    return $self;
}

sub save {
    my ($self) = @_;    

    my $deflated_filters   = to_json([ map { $_->as_hash } $self->filters->@* ]);
    my $deflated_groupings = to_json([ map { $_->as_hash } $self->groupings->@* ]);

    $self->md5($self->generate_md5);

    $self->dbh->do(
        q{
            INSERT INTO query SET
                md5            = ?,
                user_id        = ?,
                dataset_id     = ?,
                topic_id       = ?,
                filters        = ?,
                groupings      = ?,
                editor         = ?,
                params         = ?,
                date_last_exec = NOW()
            ON DUPLICATE KEY UPDATE
                md5            = ?,
                editor         = ?,
                params         = ?,
                date_last_exec = NOW()
        },
        undef,
        $self->md5,
        ($self->user ? $self->user->id : undef),
        $self->dataset->id,
        ($self->topic ? $self->topic->id : undef),
        $deflated_filters,
        $deflated_groupings,
        $self->editor,
        to_json($self->params),
        $self->md5,
        $self->editor,
        to_json($self->params),
    );

    my $id = $self->dbh->last_insert_id(undef, undef, undef, undef);

    unless ($id) {
        ($id) = $self->dbh->selectrow_array(
            "SELECT id FROM query WHERE md5 = ?",
            undef,
            $self->md5,
        );
    }

    $self->id($id);

    for my $result ($self->results->@*) {
        next if $result->id;
        $result->query($self);
        $result->user($self->user);
        $result->save;
    }

    return $self;
}

sub update_name {
    my ($self) = @_;

    $self->dbh->do(
        "UPDATE query SET name = ?, date_last_exec = NOW() WHERE id = ?",
        undef,
        $self->name,
        $self->id,
    );

    return $self;
}

1;
