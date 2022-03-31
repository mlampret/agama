package Agama::Role::DB;

use Agama::Common::DB;

use Mouse::Role;

sub dbh    { Agama::Common::DB->instance->dbh }
sub dbh_ds { Agama::Common::DB->instance->dbh_ds($_[1]) }

1;