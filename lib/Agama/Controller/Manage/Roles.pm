package Agama::Controller::Manage::Roles;

use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Roles;

sub list {
    my ($self) = @_;

    my $roles = Agama::Model::Roles->new->get;
    
    $self->render(
        roles => $roles,
    );
}

sub add {
    my ($self) = @_;

    my $role = Agama::Model::Role->new(
        name => $self->param('name'),
    );

    $role->save;

    return $self->redirect_to(
        $self->url_for('manage_role', role_id => $role->id)
    );
}

1;

