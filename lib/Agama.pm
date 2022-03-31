package Agama;
use Mojo::Base 'Mojolicious';
use Mojo::IOLoop;

use Agama::Common::DB;
use Agama::Model::User;
use Agama::Model::Datasets;

# This method will run once at server start
sub startup {
    my $self = shift;

    # command line interface
    push @{$self->commands->namespaces}, 'Agama::Command';

    # ensure static files get reloaded
    $self->plugin('Agama::Plugin::VersionDir');

    # Load configuration from hash returned by config file
    $self->plugin('Config');

    # OAuth2    
    $self->plugin('OAuth2', {
        google => {
            key    => $self->config->{apis}->{google}->{key},
            secret => $self->config->{apis}->{google}->{secret},
        },
    });

    # Helpers
    
    my $current_user = undef;
    
    $self->helper(user => sub {
        my ($c) = shift;
        if (my $user_id = $c->session('user_id')) {
            return $current_user if $current_user;

            my $user = Agama::Model::User->new(id => $user_id)->load;

            unless ($user) {
                $c->app->log->warn("Unable to load user, deleting session");
                $c->session(user_id => '');
                $c->redirect_to('login');
                return;
            }

            $current_user = $user;
            # update session
            $c->session(is_admin => $user->is_admin);

            if (!$user->sec_since_active || $user->sec_since_active > 10) {
                Mojo::IOLoop->timer(0.25 => sub { $user->update_last_active });
            }

            return $user;
        }
        return undef;
    });

    # Configure the application
    $self->secrets($self->config->{secrets});

    # Router
    my $r = $self->routes;

    # query condition
    $r->add_condition(query => sub {
        my ($route, $c, $captures, $hash) = @_;
        for my $key (keys %$hash) {
            my $param = $c->req->url->query->param($key);
            return undef unless defined $param && $param eq $hash->{$key};
        }
        return 1;
    });

    # authentication condition
    my $redirect_to_login;

    $r->add_condition(auth => sub {
        my ($route, $c) = @_;
        $redirect_to_login = 1
            unless $c->session('user_id') && $c->user && $c->user->is_enabled;
    });

    # admin condition
    $r->add_condition(admin => sub {
        my ($route, $c) = @_;
        return $c->user->is_admin;
    });

    # Routes
    $r->get('/login')
        ->name('login')
        ->to('auth#login');

    $r->get('/auth/google')
        ->name('login_google')
        ->to('auth#google');

    $r->get('/logout')
        ->name('logout')
        ->to('auth#logout');
        
    # admin required
    $r->get('/manage/users')
        ->requires(auth => 1, admin => 1)
        ->name('manage_users')
        ->to('manage-users#list');

    $r->post('/manage/add_user')
        ->requires(auth => 1, admin => 1)
        ->name('manage_add_user')
        ->to('manage-users#add');

    $r->get('/manage/users/:user_id')
        ->requires(auth => 1, admin => 1)
        ->name('manage_user')
        ->to('manage-user#show');

    $r->post('/manage/users/:user_id/update')
        ->requires(auth => 1, admin => 1)
        ->name('manage_user_update')
        ->to('manage-user#update');

    $r->get('/manage/datasets')
        ->requires(auth => 1, admin => 1)
        ->name('manage_datasets')
        ->to('manage-datasets#list');

    $r->get('/manage/datasets/:dataset_id')
        ->requires(auth => 1, admin => 1)
        ->name('manage_dataset')
        ->to('manage-dataset#show');

    $r->get('/manage/roles')
        ->requires(auth => 1, admin => 1)
        ->name('manage_roles')
        ->to('manage-roles#list');

    $r->post('/manage/add_role')
        ->requires(auth => 1, admin => 1)
        ->name('manage_add_role')
        ->to('manage-roles#add');

    $r->get('/manage/roles/:role_id')
        ->requires(auth => 1, admin => 1)
        ->name('manage_role')
        ->to('manage-role#show');

    $r->get('/manage/roles/:role_id/delete')
        ->requires(auth => 1, admin => 1)
        ->name('role_delete')
        ->to('manage-role#delete');

    $r->get('/manage/roles/:role_id/add_user')
        ->requires(auth => 1, admin => 1)
        ->name('role_add_user')
        ->to('manage-role#add_user');

    $r->get('/manage/roles/:role_id/remove_user')
        ->requires(auth => 1, admin => 1)
        ->name('role_remove_user')
        ->to('manage-role#remove_user');

    $r->get('/manage/roles/:role_id/add_dataset')
        ->requires(auth => 1, admin => 1)
        ->name('role_add_dataset')
        ->to('manage-role#add_dataset');

    $r->get('/manage/roles/:role_id/remove_dataset')
        ->requires(auth => 1, admin => 1)
        ->name('role_remove_dataset')
        ->to('manage-role#remove_dataset');

    $r->get('/manage/admins')
        ->requires(auth => 1, admin => 1)
        ->name('manage_admins')
        ->to('manage-admins#list');

    $r->get('/manage/developers')
        ->requires(auth => 1, admin => 1)
        ->name('manage_developers')
        ->to('manage-developers#list');

    # authentication required
    $r->get('/')
        ->requires('auth')
        ->name('home')
        ->to('datasets#list');

    $r->get('/account')
        ->requires('auth')
        ->name('account')
        ->to('account#info');

    $r->get('/datasets')
        ->requires('auth')
        ->name('datasets')
        ->to('datasets#list');

    $r->get('/datasets/:dataset_id/query')
        ->requires('auth')
        ->name('dataset_query')
        ->to('dataset#query');

    $r->get('/datasets/:dataset_id/exec')
        ->requires('auth')
        ->name('dataset_exec')
        ->to('dataset#exec');

    $r->get('/my/queries')
        ->requires('auth')
        ->name('my_queries')
        ->to('my_queries#list');

    $r->get('/my/history')
        ->requires(auth => 1)
        ->name('my_history')
        ->to('my_queries#list', mode => 'history');

    $r->get('/queries')
        ->requires(auth => 1,)
        ->name('queries')
        ->to('queries#list', mode => 'saved');

    $r->get('/queries/:query_id')
        ->requires('auth')
        ->name('query')
        ->to('query#show');

    $r->post('/queries/:query_id/save')
        ->requires('auth')
        ->name('save_query')
        ->to('query#save');

    $r->post('/queries/:query_id/remove')
        ->requires('auth')
        ->name('remove_query')
        ->to('query#remove');

    $r->get('/results/:result_id/csv')
        ->requires('auth')
        ->name('result_csv')
        ->to('result#csv');

    # Hooks

    # compact html - disabled as it disturbs custom queries textarea content
    #$self->hook(after_render => sub {
    #    my ($c, $output, $format) = @_;
    #
    #    return unless $format eq 'html';
    #
    #    $$output =~s! \s* \n+ \s+ !\n!sgx
    #        if $self->mode eq 'production';
    #});

    # reset db connections
    $self->hook(before_routes => sub {
        Agama::Common::DB->instance->reset;
    });

    # reset global vars
    $self->hook(before_dispatch => sub {
        $current_user = undef;
        $redirect_to_login = 0;
    });

    $self->hook(around_action => sub {
        my ($next, $c, $action, $last) = @_;
        if ($redirect_to_login) {
            $c->flash(login_dest => $c->url_with());
            $c->redirect_to('login');
        } else {
            $next->();
        }
    });
}

1;
