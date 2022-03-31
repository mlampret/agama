package Agama::Model::Role;

use Agama::Model::Datasets;
use Agama::Model::Users;

use Mouse;

with 'Agama::Role::DB';

has id   => (is => 'rw', isa => 'Int');
has name => (is => 'rw', isa => 'Str');

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM role WHERE id = ?",
        {Slice => {}},
        $self->id,
    );

    $self->name($row->{name});

    return $self;
}

sub save {
    my ($self) = @_;
    
    if ($self->id) {
        $self->dbh->do(
            "UPDATE role SET name = ? WHERE id = ?",
            undef,
            $self->id,
        );
    } else {
        $self->dbh->do(
            "INSERT INTO role SET name = ?",
            undef,
            $self->name,
        );
        $self->id($self->dbh->last_insert_id(undef, undef, undef, undef));
    }

    return $self;
}

sub delete {
    my ($self) = @_;

    if ($self->users->@*) {
        warn "Can't delete role with users attached ".$self->id;
        return $self;
    }

    $self->dbh->do(
        "DELETE FROM role_user WHERE role_id = ?",
        undef,
        $self->id,
    );

    $self->dbh->do(
        "DELETE FROM role_dataset WHERE role_id = ?",
        undef,
        $self->id,
    );

    $self->dbh->do(
        "DELETE FROM role WHERE id = ?",
        undef,
        $self->id,
    );

    return undef;
}

# user

sub users {
    my ($self) = @_;
    return Agama::Model::Users->new->get_for_role($self);
}

sub add_user {
    my ($self, $user) = @_;

    $self->dbh->do(
        "INSERT INTO role_user SET role_id = ?, user_id = ? ON DUPLICATE KEY UPDATE user_id = ?",
        undef,
        $self->id,
        $user->id,
        $user->id,
    );

    return $self;
}

sub remove_user {
    my ($self, $user) = @_;

    $self->dbh->do(
        "DELETE FROM role_user WHERE role_id = ? AND user_id = ?",
        undef,
        $self->id,
        $user->id,
    );

    return $self;
}

# dataset

sub datasets {
    my ($self) = @_;
    return Agama::Model::Datasets->new->get_for_role($self);
}

sub add_dataset {
    my ($self, $dataset) = @_;

    $self->dbh->do(
        "INSERT INTO role_dataset SET role_id = ?, dataset_id = ? ON DUPLICATE KEY UPDATE dataset_id = ?",
        undef,
        $self->id,
        $dataset->id,
        $dataset->id,
    );

    return $self;
}

sub remove_dataset {
    my ($self, $dataset) = @_;

    $self->dbh->do(
        "DELETE FROM role_dataset WHERE role_id = ? AND dataset_id = ?",
        undef,
        $self->id,
        $dataset->id,
    );

    return $self;
}

1;
