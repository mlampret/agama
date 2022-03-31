package Agama::Model::Query::Result;

use utf8;
use JSON;
use List::MoreUtils qw/ uniq /;
use Text::CSV;
use Time::HiRes qw/ time /;
use Mouse;

with 'Agama::Role::DB';

has id           => (is => 'rw', isa => 'Int');
has query        => (is => 'rw');
has user         => (is => 'rw');
has group_count  => (is => 'rw', default => 0);
has raw_columns  => (is => 'rw', default => sub { [] });
has raw_rows     => (is => 'rw', default => sub { [] });
has statement    => (is => 'rw');
has exec_time    => (is => 'rw');
has matrix       => (is => 'rw', lazy_build => 1);
has date_created => (is => 'rw');

# TODO:
# sub data
# sub is_data_numeric
# sub get_numeric_data (for charts)
# sub matrix_for_output

sub _build_matrix {
    my ($self) = @_;

    my $matrix = [ $self->raw_columns ];

    for my $row ($self->raw_rows->@*) {
        push @$matrix, [ map { $row->{$_} } $self->raw_columns->@* ];
    }
    
    $matrix = $self->_apply_secondary_grouping($matrix) if $self->group_count == 2;

    return $matrix;
}

sub _apply_secondary_grouping {
    my ($self, $results) = @_;

    my $data = [];
    (undef, @$data) = @$results;

    my $col_y = $results->[0]->[0];
    my $col_x = $results->[0]->[1];

    my @values_y = uniq map { $_->[0] // 'NULL' } @$data;
    my @values_x = uniq map { $_->[1] // 'NULL' } @$data;

    my $data_hr = {};
    $data_hr->{ $_->[0] // 'NULL' }->{ $_->[1] // 'NULL' } = $_->[2] for @$data;

    my $new = [[ $col_x ]];

    for my $y (@values_y) {
        push($new->[0]->@*, $_) for (map { $_ && $_ eq 'NULL' ? undef : $_ } @values_x);
        last;
    }
    
    for my $y (@values_y) {
        my @row = ("$col_y: ".($y // ''));
        push @row, $data_hr->{$y}->{$_} for @values_x;
        push @$new, \@row;
    }

    return $new;
}

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM result WHERE id = ?",
        {Slice => {}},
        $self->id,
    );

    $self->query(Agama::Model::Query->new(id => $row->{query_id})->load);
    $self->user(Agama::Model::User->new(id => $row->{user_id})->load);
    $self->matrix($row->{matrix} ? from_json($row->{matrix}) : []);
    $self->statement($row->{statement});
    $self->exec_time($row->{exec_time});
    $self->date_created($row->{date_created});
    
    return $self;
}

sub save {
    my ($self) = @_;

    $self->dbh->do(
        q{
            INSERT INTO result SET
                query_id = ?,
                user_id = ? ,
                date_created = NOW(),
                statement = ?,
                exec_time = ?, 
                matrix = ?
        },
        undef,
        $self->query->id,
        ($self->user ? $self->user->id : undef),
        $self->statement,
        $self->exec_time,
        to_json($self->matrix),
    );

    $self->id($self->dbh->last_insert_id(undef, undef, undef, undef));

    return $self;
}

sub csv_string {
    my ($self) = @_;

    my @out;
    my $csv = Text::CSV->new;
    for my $row ($self->matrix->@*) {
        $csv->combine($row->@*);
        push @out, $csv->string;
    }
    return join "\n", @out;
}

sub column_names {
    my ($self) = @_;
    (undef, my @names) = map { $_ } $self->matrix->[0]->@*;
    return @names;
}

sub row_names {
    my ($self, %args) = @_;
    (undef, my @names) = map { $_->[0] } $self->matrix->@*;
    return @names;
}

sub column_names_for_print {
    my ($self) = @_;
    return map { $_ // 'NULL' || ($_ eq '' ? '-' : $_) } $self->column_names;
}

sub row_names_for_print {
    my ($self) = @_;
    return map { $_ // 'NULL' || ($_ eq '' ? '-' : $_) } $self->row_names;
}

1;
