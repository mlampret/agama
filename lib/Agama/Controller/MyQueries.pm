package Agama::Controller::MyQueries;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::Queries;

sub list {
    my ($self) = @_;
    
    my $mode = $self->param('mode');
    
    $mode //= 'by_user';

    my $queries = Agama::Model::Queries->new->$mode(user => $self->user);

    $self->render(
        queries => $queries,
    );
}

1;
