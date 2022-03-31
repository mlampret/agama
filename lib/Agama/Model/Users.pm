package Agama::Model::Users;

use Agama::Model::User;

use Mouse;

with 'Agama::Role::DB';

sub get {
    my ($self) = @_;

    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT u.*,
                   UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(date_last_active)
                   AS sec_since_active
              FROM user u
          ORDER BY u.first_name, u.last_name
        },
        {Slice => {}},
    );

    my $users;

    for my $row (@$rows) {
        push @$users, Agama::Model::User->new(%$row);
    }

    return $users;
}

sub get_for_dataset {
    my ($self, $dataset) = @_;
    
    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT u.*
              FROM user u
              JOIN role_user ru ON ru.user_id = u.id
              JOIN role_dataset rd ON rd.role_id = ru.role_id
             WHERE rd.dataset_id = ?
          GROUP BY u.id
          ORDER BY u.first_name, u.last_name
        },
        {Slice => {}},
        $dataset->id,
    );

    my $users = [];

    for my $row (@$rows) {
        push @$users, Agama::Model::User->new(%$row);
    }
    
    return $users;
}

sub get_for_role {
    my ($self, $role) = @_;
    
    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT u.*
              FROM user u
              JOIN role_user ru ON ru.user_id = u.id
             WHERE ru.role_id = ?
          GROUP BY u.id
          ORDER BY u.first_name, u.last_name
        },
        {Slice => {}},
        $role->id,
    );

    my $users = [];

    for my $row (@$rows) {
        push @$users, Agama::Model::User->new(%$row);
    }
    
    return $users;
}


1;
