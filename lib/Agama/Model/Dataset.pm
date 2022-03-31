package Agama::Model::Dataset;

use Agama::Model::Dataset::Filter;
use Agama::Model::Dataset::Grouping;
use Agama::Model::Dataset::Topic;
use Agama::Model::Roles;
use Agama::Model::Users;

use Mouse;

with 'Agama::Role::DB';

has id          => (is => 'ro', isa => 'Int');
has database	=> (is => 'rw', isa => 'Str');
has name        => (is => 'rw', isa => 'Str');
has description => (is => 'rw', isa => 'Str');
has from        => (is => 'rw', isa => 'Str');
has select      => (is => 'rw', isa => 'Str');
has group_by    => (is => 'rw', isa => 'Str');
has topics      => (is => 'ro', lazy_build => 1);
has filters     => (is => 'ro', lazy_build => 1);
has groupings   => (is => 'ro', lazy_build => 1);

sub _build_topics {
    my ($self) = shift;

    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT *
              FROM topic
             WHERE dataset_id = ?
               AND status != 'disabled'
          ORDER BY FIELD(status, 'default') DESC, name
        },
        {Slice => {}},
        $self->id,
    );

    my $topics = [];

    for my $row (@$rows) {
        push @$topics, Agama::Model::Dataset::Topic->new(%$row);
    }

    return $topics;
}

sub _build_filters {
    my ($self) = shift;

    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT *
              FROM filter
             WHERE dataset_id = ?
               AND status != 'disabled'
          ORDER BY FIELD(status, 'required') DESC, name
        },
        {Slice => {}},
        $self->id,
    );

    my $filters = [];

    for my $row (@$rows) {
        push @$filters, Agama::Model::Dataset::Filter->new(%$row, dataset => $self);
    }

    return $filters;
}

sub _build_groupings {
    my ($self) = shift;

    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT *
              FROM grouping
             WHERE dataset_id = ?
               AND status != 'disabled'
          ORDER BY name
        },
        {Slice => {}},
        $self->id,
    );

    my $groupings = [];

    for my $row (@$rows) {
        push @$groupings, Agama::Model::Dataset::Grouping->new(%$row);
    }

    return $groupings;
}

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM dataset WHERE id = ?",
        {Slice => {}},
        $self->id,
    );
    
    $self->database($row->{database});
    $self->name($row->{name});
    $self->description($row->{name});
    $self->from($row->{from});
    $self->select($row->{select});
    $self->group_by($row->{group_by});

    return $self;
}

sub users {
    my ($self) = @_;

    return Agama::Model::Users->new->get_for_dataset($self);
}

sub roles {
    my ($self) = @_;

    return Agama::Model::Roles->new->get_for_dataset($self);
}

1;
