package Agama::Command::queries;

use Mojo::Base 'Mojolicious::Command';

use Data::Dumper;

use Agama::Model::Queries;

has description => 'Agama Query related commands';
has usage       => "Usage: APPLICATION queries [delete_broken|delete_old|kill_long_running]\n";

sub run {
    my ($self, $action, @args) = @_;

    $self->$action(@args);
}

sub delete_broken {
    my ($self, @args) = @_;

    my $rows_deleted = Agama::Model::Queries->new->delete_broken;
    
    print "Rows deleted: $rows_deleted\n";
}

sub delete_old {
    my ($self, @args) = @_;

    my $rows_deleted = Agama::Model::Queries->new->delete_old;
    
    print "Rows deleted: $rows_deleted\n";
}

sub kill_long_running {
    my ($self, @args) = @_;    

    my $queries = Agama::Model::Queries->new;
    my @killed;

    push @killed, $queries->kill_long_running;
    print Dumper \@killed if scalar @killed;

    if ($args[0] && $args[0] eq '--loop') {
        while (1) {
            @killed = ();
            sleep 2;
            push @killed, $queries->kill_long_running;
            print Dumper \@killed if scalar @killed;
        }
    }

    print "Done\n";
}

sub update_md5 {
    my $queries = Agama::Model::Queries->new;

    $queries->update_md5;    
    
}

1;
