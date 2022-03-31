package Agama::Model::Queries;

use Agama::Model::Dataset;
use Agama::Model::Query::Result;
use Agama::Model::Query;

use JSON;
use Mouse;

with 'Agama::Role::DB';
with 'Agama::Role::Config';

sub by_user {
    my ($self, %args) = @_;

    my $user_id = $args{user}->id;

    return $self->_get(qq{
        SELECT q.*
          FROM query q
          JOIN dataset d ON d.id = q.dataset_id
         WHERE q.name IS NOT NULL
           AND q.user_id = $user_id
      ORDER BY date_last_exec DESC, id DESC
         LIMIT 50
    });
}

sub saved {
    my ($self, %args) = @_;

    my $and_dataset_id = '';

    my $limit = 'LIMIT 50';

    if ($args{user}) {
        my @ds_ids = $args{user}->allowed_dataset_ids;
        my $ds_ids_str = join(', ', @ds_ids, 0);
        $and_dataset_id = "AND d.id IN($ds_ids_str)";
        $limit = 'LIMIT 100';
    }
    
    my $and_search = '';
    
    if ($args{search}) {
        my @search = grep { length >= 2 } split /\W+/, $args{search};
        $and_search =
            join ' AND ',
            map { "(q.name LIKE '%$_%' OR d.name LIKE '%$_%' OR d.description LIKE '%$_%')" }
            @search;
        $and_search = "AND ($and_search)" if $and_search;
        $limit = '';
    }

    return $self->_get(qq{
        SELECT q.*
          FROM query q
          JOIN dataset d ON d.id = q.dataset_id
         WHERE q.name IS NOT NULL
          $and_dataset_id
          $and_search
      ORDER BY date_last_exec DESC, id DESC
        $limit
    });
}

sub history {
    my ($self, %args) = @_;

    my $and_user_id = '';
    my $and_dataset_id = '';

    if (my $user = $args{user}) {
        my @ds_ids      = $user->allowed_dataset_ids;
        my $ds_ids_str  = join(', ', @ds_ids, 0);
        $and_dataset_id = "AND d.id IN($ds_ids_str)";
        $and_user_id    = "AND user_id = ".$user->id;
    }

    return $self->_get(qq{
        SELECT q.*,
               d.name AS dataset_name,
               (SELECT MAX(id) FROM result WHERE query_id = q.id $and_user_id) AS result_id
          FROM query q
          JOIN dataset d ON d.id = q.dataset_id
         WHERE 1
          $and_dataset_id
      GROUP BY q.id
      ORDER BY result_id DESC
         LIMIT 50
    });
}

sub _get {
    my ($self, $stmt) = @_;

    my $qrows = $self->dbh->selectall_arrayref(
        $stmt,
        {Slice => {}},
    );

    my @query_ids    = map { $_->{id} } (@$qrows, {id => 0});
    my $query_ids_ph = join ', ', map { '?' } @query_ids;

    my $rrows = $self->dbh->selectall_arrayref(
        "SELECT * FROM result WHERE query_id IN ($query_ids_ph) ORDER BY id DESC, date_created",
        {Slice => {}},
        @query_ids,
    );

    my $queries;

    for my $qrow (@$qrows) {
        my $name  = ($qrow->{name} || $qrow->{dataset_name});

        my $query = Agama::Model::Query->new(
            %$qrow,
            groupings => ($qrow->{groupings} ? from_json($qrow->{groupings}) : []),
            name      => $name,
            params    => ($qrow->{params} ? from_json($qrow->{params}) : {}),
            # todo: not ideal, load datasets in advance with one query
            dataset   => Agama::Model::Dataset->new(id => $qrow->{dataset_id})->load,
        );
        $query->results([ $query->last_result ]);
        push @$queries, $query;
    }

    return $queries;
}

sub delete_broken {
    my ($self) = @_;
    
    my $rows_deleted = 0;

    # queries without result    
    $rows_deleted += $self->dbh->do(q{
        DELETE q
          FROM query q
     LEFT JOIN result r ON r.query_id = q.id
         WHERE r.id IS NULL
           AND q.name IS NULL
    });

    # results without query
    $rows_deleted += $self->dbh->do(q{
        DELETE r
          FROM result r
     LEFT JOIN query q ON q.id = r.query_id
         WHERE q.id IS NULL
    });
    
    return $rows_deleted;
}

sub delete_old {
    my ($self) = @_;
    
    my $rows_deleted = $self->dbh->do(q{
        DELETE
          FROM query
         WHERE name IS NULL
           AND date_last_exec < DATE_SUB(NOW(), INTERVAL 2 DAY)
    });

    $rows_deleted += $self->delete_broken;

    return $rows_deleted;
}

sub kill_long_running {
    my ($self, @args) = @_;
    my @killed;

    for my $database (keys $self->config->{dataset_dbs}->%*) {
        my $rows = $self->dbh_ds($database)->selectall_arrayref("SHOW FULL PROCESSLIST", {Slice => {}});

        for my $row ($rows->@*) {
            next unless $row->{Time} > $self->config->get('query_exec_timeout')
                 && $row->{Info} && $row->{Info} =~ m/-- AGAMA QUERY --/;
            $self->dbh_ds($database)->do("KILL ".$row->{Id});
            push @killed, $row;
        }
    }
    return @killed;
}

sub update_md5 {
    my ($self, @args) = @_;
    
    my $query_ids = $self->dbh->selectcol_arrayref(
        "SELECT id FROM query ORDER BY id DESC",
    );
    
    for my $qid (@$query_ids) {
        my $query = Agama::Model::Query->new(id => $qid)->load;

        my $old_md5 = $query->md5;

        my $has_params = $query->params && keys $query->params->%*;

        unless ($has_params) {
            next unless $query->editor eq 'sql_composer';
            $query->params({
                topic     => { id => $query->topic->id },
                filters   => [ map { $_->as_hash } $query->filters->@* ],
                groupings => [ map { $_->as_hash } $query->groupings->@* ],
            }); 
        }

        $query->md5($query->generate_md5);
        my $new_md5 = $query->md5;
        
        if (! $has_params || ($old_md5 // '') ne ($new_md5 // '')) {
            eval {
                $self->dbh->do(
                    "UPDATE query SET md5 = ?, params = ? WHERE id = ?",
                    undef,
                    $new_md5,
                    to_json($query->params),
                    $query->id,
                );
            };

            if ($@) {
                warn "Failed to update: ".$query->id."\n";
                die $@;
                next;
            }

            print "Updated: ".$query->id
                . ", ".($old_md5 // '')
                . " => $new_md5\n";
        }
    }
}

1;
