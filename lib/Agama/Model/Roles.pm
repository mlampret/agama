package Agama::Model::Roles;

use Agama::Model::Role;

use Mouse;

with 'Agama::Role::DB';

sub get {
    my ($self) = @_;

    my $rows = $self->dbh->selectall_arrayref(
        "SELECT * FROM role ORDER BY name",
        {Slice => {}},
    );

    my $roles = [];

    for my $row (@$rows) {
        push @$roles, Agama::Model::Role->new(%$row);
    }

    return $roles;
}

sub get_for_user {
    my ($self, $user) = @_;

    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT r.*
              FROM role r
              JOIN role_user ru ON ru.role_id = r.id
             WHERE ru.user_id = ?
          ORDER BY name
        },
        {Slice => {}},
        $user->id,
    );

    my $roles = [];

    for my $row (@$rows) {
        push @$roles, Agama::Model::Role->new(%$row);
    }

    return $roles;
}

sub get_for_dataset {
    my ($self, $dataset) = @_;

    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT r.*
              FROM role r
              JOIN role_dataset rd ON rd.role_id = r.id
             WHERE rd.dataset_id = ?
          ORDER BY name
        },
        {Slice => {}},
        $dataset->id,
    );

    my $roles = [];

    for my $row (@$rows) {
        push @$roles, Agama::Model::Role->new(%$row);
    }

    return $roles;
}


1;
