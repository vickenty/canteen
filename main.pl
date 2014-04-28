use Mojolicious::Lite;
use POSIX qw/setlocale LC_ALL/;
use DateTime;
use Canteen::Common qw(:all);
use Canteen::User qw(:all);
use Canteen::Menu qw(:all);

plugin 'DefaultHelpers';

helper handle_error => sub {
    my ($self, $error) = @_;
    if (ref $error eq "Canteen::Error") {
        $self->stash(error => $error->{message});
    } else {
        die $error;
    }
    return undef;
};

helper login => sub {
    my ($self, $email, $password) = @_;
    my $user = get_user_by_email($email);
    if ($user && validate_password($user->{password}, $password)) {
        record_login($user->{rowid}, $self->tx->remote_address);
        $self->session->{user_id} = $user->{rowid};
        return $user;
    }
};

helper authenticate => sub {
    my $self = shift;
    my $user = get_user($self->session->{user_id});
    return unless ($user->{active});
    $self->stash(current_user => $user);
    return $user;
};

helper url_match => sub {
    my ($self, $match) = @_;
    $self->req->url->to_string =~ /^$match/;
};

helper current_user => sub {
    my ($self, $attr) = @_;
    my $user = $self->stash('current_user');
    return ($user && $attr) ? $user->{$attr} : $user;
};

helper param_validate => sub {
    my ($self, $name) = @_;
    my $value = $self->param($name);
    if ($name =~ /date/) {
        return ($value =~ /\A[0-9]{4}(?:-[0-9]{2}){2}\z/) ? $value : undef;
    }

    return $value;
};

helper calendar_date_classes => sub {
    my ($self, $item) = @_;
    return join(" ",
        "calendar-item",
        $item->{today} ? "calendar-today" : (),
        $item->{local_day_of_week} == 1 ? "calendar-first" : (),
        $item->{day_of_week} > 5 ? "calendar-weekend" : ()
    );
};

helper field => sub {
    my $self = shift;
    return $self->include("parts/field", @_);
};

helper maybe => sub {
    my ($self, $name, $value, $attr) = @_;

    if (my $default = $self->stash->{$name}) {
        return (($attr || $name) => ($value || $default));
    }

    return ();
};

helper save_user => sub {
    my $self = shift;

    my $uid = $self->param('uid');
    my $email = $self->param('email');
    my $password = $self->param('password');
    my $active = $self->param('active');
    my $digest = $self->param('mail_digest');

    unless ($self->stash('user')) {
        $self->stash(user => {
            email => $email,
            password => $password,
            active => $active,
            mail_digest => $digest,
        });
    }

    eval {
        fail "Password can't be empty." unless ($uid || $password);
        fail 'Passwords do not match.' unless ($password eq $self->param('confirm'));
        1;
    } or do {
        return $self->handle_error($@);
    };

    eval {
        if ($uid) {
            update_user($uid, $email, $password, $active, $digest);
        } else {
            create_user($email, $password, $active, $digest);
        }
        return 1;
    } or do {
        my $error = $@;
        return $self->handle_error($error);
    };
};

helper get_user => sub {
    my $self = shift;
    my $user = get_user($self->param('uid'));
    $self->stash(user => $user);
    return $user;
};


helper success => sub {
    my ($self, $msg) = @_;
    $self->flash(type => 'success', message => $msg);
};

get '/vote' => sub {
    my $self = shift;

    my $date = today;
    my $menu = get_menu($date);

    $self->stash(
        date => $date,
        menu => $menu,
    );
    return $self->render('vote');
};

post '/vote' => sub {
    my $self = shift;

    my $date = $self->param_validate("date");
    unless ($date) {
        $self->respond_to(
            json => sub { $self->render(json => { result => "bad date" }) },
            any => sub { $self->render_not_found unless ($date); },
        );
    }

    my %votes = map { substr($_, 5) => $self->param($_) } grep /^vote_/, sort $self->param;

    save_votes($date, %votes);
	
    $self->respond_to(
        json => sub { $self->render(json => { result => "ok" }); },
        html => sub { $self->redirect_to("/vote"); },
    );
};

any '/refresh' => sub {
    my $self = shift;

    my $date = $self->param_validate("date");

    my $today = today;
    my $menu = get_menu($today);

    my $refresh = $date ne $today && $menu && @$menu;

    return $self->render(json => { refresh => $refresh });
};

get '/signin' => sub { shift->render('signin'); };

post '/signin' => sub {
    my $self = shift;
    my $user = $self->login($self->param("email"), $self->param('password'));

    unless ($user) {
        $self->flash(type => 'error', message => "Invalid e-mail address or password.");
        return $self->redirect_to('/signin');
    }

    return $self->redirect_to('view');
};

any '/signout' => sub {
    my $self = shift;
    delete $self->session->{user_id};

    $self->flash(type => 'success', message => "Signed out.");
    $self->redirect_to('/signin');
};

get '/unsubscribe/#token' => [ token => qr/[a-z0-9.]+/ ] => sub {
    my $self = shift;

    my $user = check_token $self->param('token'), $ENV{EMAIL_SECRET};

    if ($user) {
        unsubscribe_user $user->{rowid};

        $self->stash(email => $user->{email});
        return $self->render('unsubscribed');
    }

    return $self->render_not_found;
};

under sub {
    my $self = shift;
    unless ($self->authenticate) {
        $self->render("signin", status => 403);
        return 0;
    }

    return 1;
};

get '/view' => sub {
    my $self = shift;
    my $votes = get_recent_votes();
    $self->stash(
        votes => $votes,
    );
    return $self->render('view');
};

get '/edit' => sub {
    my $self = shift;
    $self->stash(dates => get_menu_dates());
    return $self->render('index');
};

post '/edit' => sub {
    my $self = shift;
    my $date = $self->param_validate('date');
    unless ($date) {
        $self->flash(type => "error", message => "Invalid date. Please use YYYY-MM-DD format.");
        return $self->redirect_to('edit');
    }
    return $self->redirect_to('editdate' => { date => $date });
};

get '/edit/:date' => sub {
    my $self = shift;

    my $date = $self->param_validate('date');
    return $self->render_not_found unless ($date);

    $self->stash(menu => get_menu($date));

    return $self->render('edit');
};

post '/edit/:date' => sub {
    my $self = shift;

    my $date = $self->param_validate('date');
    return $self->render_not_found unless ($date);

    my @items = map { $self->param($_) || () } grep /name_/, sort $self->param;
    save_menu($date, @items);

    $self->flash(type => "success", message => "Changes saved.");
    return $self->redirect_to("/edit");
};

get '/users' => sub {
    my $self = shift;

    $self->stash(users => list_users);

    return $self->render('users');
};

get '/users/new' => sub {
    my $self = shift;

    $self->stash(user => { active => 1});

    $self->render("users_new");
};

post '/users/new' => sub {
    my $self = shift;

    if ($self->save_user) {
        $self->success("User created.");
        return $self->redirect_to('/users');
    } else {
        return $self->render('users_new');
    }
};

get '/users/:uid' => sub {
    my $self = shift;

    $self->get_user or return $self->render_not_found;

    return $self->render('users_edit');
};

post '/users/:uid' => sub {
    my $self = shift;

    $self->get_user or return $self->render_not_found;

    if ($self->save_user) {
        $self->success('User saved.');
        return $self->redirect_to('/users');
    } else {
        return $self->render('users_edit');
    }
};


DateTime->DefaultLocale(setlocale(LC_ALL, "") || "C");
app->secrets([$ENV{"SESSION_SECRET"} || get_token]);
app->start;
