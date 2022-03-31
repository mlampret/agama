package Agama::Model::Datasets;

use Agama::Model::Dataset;

use Mouse;

with 'Agama::Role::DB';

sub get {
    my ($self, %args) = @_;

    my $and_dataset_id = '';

    if ($args{user}) {
        my @ds_ids = $args{user}->allowed_dataset_ids;
        my $ds_ids_str = join(', ', @ds_ids, 0);
        $and_dataset_id = "AND id IN($ds_ids_str)";
    }

    my $rows = $self->dbh->selectall_arrayref(
        "SELECT * FROM dataset WHERE 1 $and_dataset_id ORDER BY name",
        {Slice => {}},
    );

    my $datasets;

    for my $row (@$rows) {
        push @$datasets, Agama::Model::Dataset->new(%$row);
    }

    return $datasets;
}

sub get_for_user {
    my ($self, $user) = @_;
    
    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT d.*
              FROM dataset d
              JOIN role_dataset rd ON rd.dataset_id = d.id
              JOIN role_user ru ON ru.role_id = rd.role_id
             WHERE ru.user_id = ?
          GROUP BY d.id
          ORDER BY d.name
        },
        {Slice => {}},
        $user->id,
    );

    my $datasets = [];

    for my $row (@$rows) {
        push @$datasets, Agama::Model::Dataset->new(%$row);
    }

    return $datasets;

}

sub get_for_role {
    my ($self, $role) = @_;
    
    my $rows = $self->dbh->selectall_arrayref(
        q{
            SELECT d.*
              FROM dataset d
              JOIN role_dataset rd ON rd.dataset_id = d.id
             WHERE rd.role_id = ?
          GROUP BY d.id
          ORDER BY d.name
        },
        {Slice => {}},
        $role->id,
    );

    my $datasets = [];

    for my $row (@$rows) {
        push @$datasets, Agama::Model::Dataset->new(%$row);
    }

    return $datasets;

}

1;
