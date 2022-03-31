package Agama::Model::Dataset::Topic;

use Mouse;

with 'Agama::Role::DB';

has id       => (is => 'ro', isa => 'Int');
has name     => (is => 'rw', isa => 'Str');
has status   => (is => 'rw', isa => 'Str');
has select   => (is => 'rw');
has where    => (is => 'rw');
has group_by => (is => 'rw');
has order_by => (is => 'rw');

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM topic WHERE id = ?",
        {Slice => {}},
        $self->id,
    );

    $self->name($row->{name});
    $self->status($row->{status});
    $self->select($row->{select});
    $self->where($row->{where});
    $self->group_by($row->{group_by});
    $self->order_by($row->{order_by});

    return $self;
}

1;