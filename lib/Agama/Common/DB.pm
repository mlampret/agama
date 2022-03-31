package Agama::Common::DB;

use base 'Class::Singleton';

use DBI;
use Mouse;

with 'Agama::Role::Config';

has dbh     => (is => 'ro', lazy_build => 1, clearer => 'clear_dbh');
has _dbh_ds => (is => 'ro', lazy_build => 1);

sub _build_dbh {
    my ($self) = @_;
    my @config = $self->config->get('db')->@*;
    $config[3]->{PrintError} = 0;
    $config[3]->{RaiseError} = 1;
    return DBI->connect(@config);
}

sub _build__dbh_ds {
    # default => sub {{}} doesn't work since we use Class::Singleton
    # and we call ->instance instead of ->new
    return {};
}

sub dbh_ds {
    my ($self, $database) = @_;

    if (! $self->_dbh_ds->{$database}) {
        my @config = $self->config->get('dataset_dbs')->{$database}->@*;
        $config[3]->{PrintError} = 0;
        $config[3]->{RaiseError} = 1;
        $self->_dbh_ds->{$database} = DBI->connect(@config);
    }

    return $self->_dbh_ds->{$database};
}

sub reset {
    my ($self) = @_;

    $self->clear_dbh unless $self->dbh->ping;

    for my $database (keys $self->config->get('dataset_dbs')->%*) {
        next unless $self->_dbh_ds->{$database};
        delete $self->_dbh_ds->{$database} unless $self->_dbh_ds->{$database}->ping;
    }
}

1;
