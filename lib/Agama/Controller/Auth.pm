package Agama::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller';

use Agama::Model::User;

use Mojo::ByteStream 'b';
use Mojo::JSON 'j';
use Mojo::UserAgent;

sub login {
    my $self = shift;

    $self->flash(login_dest => $self->flash('login_dest'));

#    return $self->redirect_to('home')
#        if $self->session('user_id');

    $self->render;
}

sub google {
    my $self = shift;

    my $err_msg = 'Failed to login using google: ';

    $self
        ->oauth2
        ->get_token_p('google', { scope => 'email profile' })
        ->then(sub {
            my ($provider_res, @params) = shift;
            unless ($provider_res) {
                $self->app->log->error($err_msg.$self->dumper(\@params)) if @params;
                return;
            }
            return $self->service_on_success('google', $provider_res->{access_token});
        })
        ->catch(sub {
            my $response = shift;
            $self->app->log->error($err_msg.$self->dumper($response));
            $self->flash(errors => ['google_login_error']);
            $self->flash(login_dest => $self->flash('login_dest'));
            return $self->redirect_to( $self->url_for('login') );
        });
}

sub service_on_success {
    my ($self, $service_name, $access_token) = @_;

    my $service_urls = {
        google => 'https://www.googleapis.com/oauth2/v1/userinfo?access_token=$access_token',
    };

    my $service_url = $service_urls->{$service_name};
    $service_url =~s!\$access_token!$access_token!;

    my $ua = Mojo::UserAgent->new->request_timeout(5);

    my $service_user_jsonstr = $ua->get($service_url)->res->body;
    my $service_user = {};

    if ($service_name eq 'google') {
        $service_user = j( $service_user_jsonstr );
    } else {
        $service_user = j( b($service_user_jsonstr)->encode('UTF-8') );
    }

    $service_user->{service_name} = $service_name;
    $service_user_jsonstr = j( $service_user );

    $service_user->{first_name} = $service_user->{given_name}  if ($service_user->{given_name});
    $service_user->{last_name}  = $service_user->{family_name} if ($service_user->{family_name});

    # find user
    my $user = Agama::Model::User->new(email => $service_user->{email})->load;

    if (!$user && !$self->config->{autocreate_users}) {
        $self->flash(errors => ['user_not_found']);
        return $self->redirect_to( $self->url_for('login') );
    } elsif (!$user && $self->config->{autocreate_users}) {
        $user = Agama::Model::User->new(email => $service_user->{email});
        if ($self->app->mode eq 'development') {
            $user->type('admin');
        }
    }

    # user found or created, log them in
    $user->first_name($service_user->{first_name});
    $user->last_name($service_user->{last_name});
    $user->picture_url($service_user->{picture});
    $user->save->load;

    $self->session(
        expiration => $self->config->{session}->{expiration},
        user_id    => $user->id,
        is_admin   => $user->is_admin,
    );

    $self->redirect_to($self->flash('login_dest') || 'datasets');
}

sub logout {
    my $self = shift;

    # delete session
    $self->session(user_id => '');

    $self->redirect_to('login');
}

1;
