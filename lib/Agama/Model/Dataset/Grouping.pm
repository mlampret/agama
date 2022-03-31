package Agama::Model::Dataset::Grouping;

use JSON;
use Mouse;

with 'Agama::Role::DB';

has id       => (is => 'ro', isa => 'Int');
has name     => (is => 'rw', isa => 'Str');
has status   => (is => 'rw', isa => 'Str');
has select   => (is => 'rw');
has group_by => (is => 'rw', isa => 'Str');
has join     => (is => 'rw');

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM grouping WHERE id = ?",
        {Slice => {}},
        $self->id,
    );

    $self->name($row->{name});
    $self->status($row->{status});
    $self->select($row->{select});
    $self->group_by($row->{group_by});
    $self->join($row->{join});

    return $self;
}

sub as_hash {
    my ($self) = @_;

    return {
        id => $self->id,
    };
}

1;
