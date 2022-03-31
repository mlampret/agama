package Agama::Role::Config;

use Agama::Common::Config;

use Mouse::Role;

has config => (is => 'ro', lazy_build => 1);

sub _build_config {
    return Agama::Common::Config->instance;
}

1;