package Agama::Model::Dataset::Filter;

use JSON;
use Mouse;

with 'Agama::Role::DB';

has id       => (is => 'ro', isa => 'Int');
has dataset  => (is => 'rw');
has name     => (is => 'rw', isa => 'Str');
has status   => (is => 'rw', isa => 'Str');
has type     => (is => 'rw', isa => 'Str');
has join     => (is => 'rw');
has where    => (is => 'rw');
has options  => (is => 'rw');
has operator => (is => 'rw', default => 'and');
has params   => (is => 'rw', default => sub {[]});

sub load {
    my ($self) = @_;

    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM filter WHERE id = ?",
        {Slice => {}},
        $self->id,
    );

    $self->name($row->{name});
    $self->status($row->{status});
    $self->type($row->{type});
    $self->join($row->{join});
    $self->where($row->{where});
    $self->options($row->{options});

    if (! $self->dataset) {
        my $dataset = Agama::Model::Dataset->new(id => $row->{dataset_id})->load;
        $self->dataset($dataset);
    }

    return $self;
}

sub where_with_params {
    my ($self) = @_;
    my $where = $self->where;

    my @params = $self->params->@*;

    if ($self->type eq 'date_range') {
        $_ =~ s/^\s+|\s+$//g for @params;

        $params[0] = $self->_rel_date_range($params[0], 'start')
            if $params[0] !~ m/^\d{4}-\d{2}-\d{2}/;

        $params[1] = $self->_rel_date_range($params[1], 'end')
            if $params[1] !~ m/^\d{4}-\d{2}-\d{2}/;

        if ($params[0] =~ m/^\d{4}-\d{2}-\d{2}$/) {
            $params[0] .= ' 00:00:00';
            $params[0] = '"'.$params[0].'"';
        }
        if ($params[1] =~ m/^\d{4}-\d{2}-\d{2}$/) {
            $params[1] .= ' 23:59:59';
            $params[1] = '"'.$params[1].'"';
        }
    }

    $where =~ s/\?(\d+)/$params[$1-1]/g;

    for my $param (@params) {
        $where =~ s/\?/$param/;
    }

    $where = "NOT ($where)" if $self->operator eq 'and_not';

    return $where;
}

sub options_as_array {
    my ($self) = @_;

    my $result = [];

    if ($self->type eq 'enum') {
        my $rows = $self->dbh_ds($self->dataset->database)->selectall_arrayref(
            $self->options,
            {Slice => {}},
        );

        if ($rows->[0] && defined $rows->[0]->{name} && defined $rows->[0]->{value}) {
            # regular select that returns rows with name, value, selected
            $result = $rows;
        }
        elsif ($rows->[0] && defined $rows->[0]->{Type} && $rows->[0]->{Type} =~ /(?:enum|set)\(([^\)]+)\)/) {
            # show columns
            my $values = $1;
            my (@values) = map { s/^'|'$//gr } split /,/, $values;

            $result = [ map { { name => $_, value => $_, selected => 0 } } @values ];
        }
    }

    return $result;
}

sub as_hash {
    my ($self) = @_;

    my %operator = $self->operator
        ? (operator => $self->operator)
        : ();

    my %params = scalar($self->params->@*)
        ? (params => $self->params)
        : ();

    return {
        id => $self->id,
        %operator,
        %params,
    };
}

sub _rel_date_range {
    my ($self, $rel_date, $trim_mode) = @_;

    my $hms = $trim_mode && $trim_mode eq 'end' ? '23:59:59' : '00:00:00';

    my ($d, $trim) = split /\//, $rel_date; 

    my $str = '';

    for my $e (split /([+-])/, $d) {
        if ($e eq 'now') {
            $str .= 'NOW()';
        } elsif ($e eq '+') {
            $str = "DATE_ADD($str, INTERVAL ";
        } elsif ($e eq '-') {
            $str = "DATE_SUB($str, INTERVAL ";
        } elsif ($e =~ m/^(\d+)([A-Za-z])$/) {
            $str .= "$1 ";
            
            my $map = {
                y => 'YEAR',
                M => 'MONTH',
                d => 'DAY',
                h => 'HOUR',
                m => 'MINUTE',
                s => 'SECOND',
            };
            $str .= $map->{$2} . ")";
        }
    }

    if ($trim && $trim_mode eq 'start') {
        my $map = {
            'y' => '%Y-01-01 00:00:00',
            'M' => '%Y-%m-01 00:00:00',
            'd' => '%Y-%m-%d 00:00:00',
            'h' => '%Y-%m-%d %H:00:00',
            'm' => '%Y-%m-%d %H:%i:00',
        };
        $str = "DATE_FORMAT($str, '$map->{$trim}')";
    }
    elsif ($trim && $trim_mode eq 'end') {
        my $map = {
            'y' => '%Y-12-31 23:59:59',
            'M' => '%Y-%m-32 23:59:59',
            'd' => '%Y-%m-%d 23:59:59',
            'h' => '%Y-%m-%d %H:59:59',
            'm' => '%Y-%m-%d %H:%i:59',
        };
        $str = "DATE_FORMAT($str, '$map->{$trim}')";
    }
    
    return $str;
}

1;
