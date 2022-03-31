package Agama::Model::User;

use Agama::Model::Roles;

use Mouse;

with 'Agama::Role::DB';

has id               => (is => 'rw', isa => 'Int');
has email            => (is => 'rw', isa => 'Str');
has first_name       => (is => 'rw');
has last_name        => (is => 'rw');
has status           => (is => 'rw');
has type             => (is => 'rw');
has picture_url      => (is => 'rw');
has date_created     => (is => 'rw');
has date_last_active => (is => 'rw');
has sec_since_active => (is => 'rw');

sub load {
    my ($self) = @_;

    my $field_name = $self->id ? 'id' : $self->email ? 'email' : undef;
    
    die "Email or id required to load a user" unless $field_name;

    my $row = $self->dbh->selectrow_hashref(
        qq{
            SELECT u.*,
                   UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(date_last_active)
                   AS sec_since_active
              FROM user u
             WHERE u.$field_name = ?
        },
        {Slice => {}},
        $self->$field_name,
    );
    
    return undef unless $row;

    $self->id($row->{id});
    $self->email($row->{email});
    $self->first_name($row->{first_name});
    $self->last_name($row->{last_name});
    $self->status($row->{status});
    $self->type($row->{type});
    $self->picture_url($row->{picture_url});
    $self->date_created($row->{date_created});
    $self->date_last_active($row->{date_last_active});
    $self->is_admin($row->{is_admin});
    $self->sec_since_active($row->{sec_since_active});

    return $self;
}

sub full_name {
    my ($self) = @_;
    return $self->first_name . ' ' . $self->last_name; 
}

sub is_enabled  { shift->status eq 'enabled'  }
sub is_disabled { shift->status eq 'disabled' }

sub is_admin     { shift->type eq 'admin'     }
sub is_developer { shift->type eq 'developer' }

sub can_develop { 
    my ($self) = @_;
    return $self->is_developer || $self->is_admin;
}

sub save {
    my ($self) = @_;
    
    if ($self->id) {
        $self->dbh->do(
            q{
                UPDATE user SET
                    email       = ?,
                    first_name  = ?,
                    last_name   = ?,
                    status      = ?,
                    type        = ?,
                    picture_url = ?
                 WHERE id = ?
            },
            undef,
            $self->email,
            $self->first_name,
            $self->last_name,
            $self->status,
            $self->type,
            $self->picture_url,
            $self->id,
        );
    } else {
        $self->dbh->do(
            q{
                INSERT INTO user SET
                    email        = ?,
                    first_name   = ?,
                    last_name    = ?,
                    type         = ?,
                    picture_url  = ?,
                    date_created = NOW()
            },
            undef,
            $self->email,
            $self->first_name,
            $self->last_name,
            $self->type // 'explorer',
            $self->picture_url,
        );
        $self->id($self->dbh->last_insert_id(undef, undef, undef, undef));
    }

    return $self;
}

sub allowed_dataset_ids {
    my ($self) = @_;

    my $ds_ids = $self->dbh->selectcol_arrayref(
        q{
            SELECT DISTINCT(rd.dataset_id)
              FROM role_dataset rd
         LEFT JOIN role r ON r.id = rd.role_id
         LEFT JOIN role_user ru ON ru.role_id = r.id
             WHERE ru.user_id = ?
          ORDER BY dataset_id
        },
        undef,
        $self->id,
    );

    return @$ds_ids;
}

sub roles {
    my ($self) = @_;

    return Agama::Model::Roles->new->get_for_user($self);
}

sub datasets {
    my ($self) = @_;

    return Agama::Model::Datasets->new->get_for_user($self);
}

sub update_last_active {
    my ($self) = @_;

    $self->dbh->do(
        "UPDATE user SET date_last_active = NOW() WHERE id = ?",
        undef,
        $self->id,
    );

    return $self;
}

1;
