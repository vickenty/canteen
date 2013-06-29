use DBI;
use Mojolicious::Lite;
use Session::Token;
use Digest::SHA qw/sha1_hex/;
use POSIX qw/strftime setlocale LC_ALL/;
use DateTime;

plugin 'DefaultHelpers';

do {
    my $generator = Session::Token->new;
    sub token_generator { $generator }
};

sub fail {
    die bless { message => shift }, "Canteen::Error";
}

sub get_db {
    DBI->connect("dbi:SQLite:main.db", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
        sqlite_unicode => 1,
    }) or die(DBI->errstr);
}

sub get_menu {
    my ($date) = @_;
    my $db = get_db;
    my $st = $db->prepare("select name from menu where date = ? order by position");
    $st->execute($date);
    my @menu;
    while (my ($name) = $st->fetchrow_array) {
        push @menu, $name;
    }
    return \@menu;
}

sub today {
    return strftime("%Y-%m-%d", localtime);
}

sub save_menu {
    my ($date, @items) = @_;
    my $db = get_db;
    my $st = $db->prepare("replace into menu (date, position, name) values (?, ?, ?)");
    foreach (0..$#items) {
        $st->execute($date, $_, $items[$_]);
    }
    $db->do("delete from menu where date = ? and position > ?", {}, $date, $#items);
}

sub save_votes {
    my ($date, %votes) = @_;
    my $db = get_db;
    my $st = $db->prepare("insert into votes (date, position, vote, user) values (?, ?, ?, ?)");
    foreach (keys %votes) {
        $st->execute($date, $_, $votes{$_}, "");
    }
}

sub push_any {
    my ($ref, $key, $val) = @_;
    if (ref $ref eq "ARRAY") {
        push @$ref, { key => $key, value => $val };
    } elsif (ref $ref eq "HASH") {
        $ref->{$key} = $val;
    } else {
        die "unknown ref type $ref";
    }
}

sub collect {
    my ($st, @types) = @_;
    my (%acc, $acc);

    my $root = shift @types;
    if ($root eq "array") {
        $acc{-1} = [];
    } else {
        $acc{-1} = {};
    }

    my $order = scalar(@types);
    my @mark = (undef) x $order;

    while (my @row = $st->fetchrow_array) {
        foreach (0..$#types) {
            unless (defined($mark[$_]) && $mark[$_] eq $row[$_]) {
                $mark[$_] = $row[$_];
                $mark[$_ + 1] = undef;

                if ($types[$_] eq "array") {
                    $acc = [];
                } else {
                    $acc = {};
                }
                $acc{$_} = $acc;
                push_any($acc{$_ - 1}, $row[$_], $acc);
            }
        }
        push_any $acc, $row[$order], [ @row[($order + 1) .. $#row] ];
    }

    return $acc{-1};
}

sub get_recent_votes {
    my $db = get_db;
    my $st = $db->prepare("select date, position, vote, count(*) from votes where date >= date('now', '-1 month') group by date, position, vote");
    $st->execute;
    my $votes = collect($st, "array", "hash", "hash");
    my $max = $db->selectrow_array("select max(position) from menu where date >= date('now', '-1 month')");
    return ($votes, $max);
}

sub new_hash_password {
    return hash_password(token_generator->get, shift);
}

sub hash_password {
    my ($salt, $password) = @_;
    return join(".", $salt, sha1_hex("$salt.$password"));
}

sub modify_user {
    my $code = shift;
    eval {
        $code->(@_);
    } or do {
        my $error = $@;
        if ($error =~ /email is not unique/i) {
            fail "There is already a user with this e-mail address.";
        }
        die $error;
    };
}

sub create_user {
    my ($email, $password, $active) = @_;
    my $hash = new_hash_password($password);
    $active = $active ? 1 : 0;

    my $db = get_db;
    modify_user sub {
        $db->do("insert into users (email, password, active, created_at) values (?, ?, ?, datetime('now'))", {}, $email, $hash, $active);
    };

}

sub update_user {
    my ($uid, $email, $password, $active) = @_;
    my $db = get_db;
    $active = $active ? 1 : 0;
    modify_user sub {
        $db->do('update users set email = ?, active = ? where rowid = ?', {}, $email, $active, $uid);
    };
    if ($password) {
        my $hash = new_hash_password($password);
        $db->do('update users set password = ? where rowid = ?', {}, $hash, $uid);
    }
}

sub list_users {
    return get_db->selectall_arrayref("select rowid, email, last_login_at, active, created_at from users", { Slice => {} });
}

sub get_user {
    my ($uid) = @_;
    return get_db->selectrow_hashref("select rowid, email, active from users where rowid = ?", {}, $uid);
}

sub get_user_by_email {
    my ($email) = @_;
    my $db = get_db;
    return get_db->selectrow_hashref("select rowid, email, password from users where active > 0 and email = ?", {}, $email);
}

sub record_login {
    my ($uid, $ip) = @_;
    my $db = get_db;
    $db->do("update users set last_login_at = datetime('now'), last_login_ip = ? where rowid = ?", {}, $ip, $uid);
}

sub change_password {
    my ($uid, $password) = @_;
    my $hash = new_hash_password($password);
    get_db->do("update users set password = ? where rowid = ?", {}, $hash, $uid);
}

sub get_menu_dates {
    my $today = DateTime->today(time_zone => 'local');
    # Beginning of last week.
    my $first = $today->clone->subtract(days => $today->local_day_of_week + 6);
    my $last = $first->clone->add(days => 21);

    my $st = get_db->prepare("select date, name from menu where date between ? and ? order by date asc, position asc");
    $st->execute($first->ymd, $last->ymd);
    my $menus = collect($st, "hash", "array");

    my @res;
    while ($first < $last) {
        my $menu = $menus->{$first->ymd};
        push @res, {
            date => $first->ymd,
            today => $first == $today,
            local_day_of_week => $first->local_day_of_week,
            day_of_week => $first->day_of_week,
            day => $first->day,
            day_name => $first->strftime("%a"),
            menu => $menu && [ map { $_->{key} } @$menu ],
        };
        $first->add(days => 1);
    }

    return \@res;
}

sub validate_password {
    my ($salted, $password) = @_;
    return 1 unless ($salted);

    my ($salt, $hash) = split /\./, $salted;
    return $salted eq hash_password($salt, $password);
}

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
    $self->req->url->to_rel =~ /^$match/;
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

    unless ($self->stash('user')) {
        $self->stash(user => {
            email => $email,
            password => $password,
            active => $active,
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
            update_user($uid, $email, $password, $active);
        } else {
            create_user($email, $password, $active);
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
    return $self->render_not_found unless ($date);

    my %votes = map { substr($_, 5) => $self->param($_) } grep /^vote_/, sort $self->param;
    save_votes($date, %votes);
	
	$self->flash(message => "Thank you! Your feedback has been submitted.");
	
    return $self->redirect_to("/vote");
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
    my ($votes, $max_items) = get_recent_votes();
    $self->stash(
        votes => $votes,
        max_items => $max_items
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
app->secret($ENV{"SESSION_SECRET"} || Session::Token->new->get);
app->start;
