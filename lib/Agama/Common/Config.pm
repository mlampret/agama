package Agama::Common::Config;

use base 'Class::Singleton';

use File::Basename;
use Mouse;

has _config => (is => 'ro', lazy_build => 1);

sub _new_instance {
    my $class = shift;
    my $self  = bless { }, $class;
    return $self;
}

sub _build__config {
    my $this_file = dirname(__FILE__);
    my $content = `cat $this_file/../../../agama.conf`;
    
    return eval $content;
}

sub get {
    my ($self, $key) = @_;

    return $self->_config->{$key};
}

1;
