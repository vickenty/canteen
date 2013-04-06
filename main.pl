use DBI;
use Mojolicious::Lite;
use Session::Token;
use Digest::SHA qw/sha1_hex/;

plugin 'DefaultHelpers';

do {
    my $generator = Session::Token->new;
    sub token_generator { $generator }
};

sub get_db {
    DBI->connect("dbi:SQLite:main.db") or die(DBI->errstr);
}

sub get_menu {
    my ($date) = @_;
    my $db = get_db;
    my $st = $db->prepare("select name from menu where date = ? order by position") or die($db->errstr);
    $st->execute($date);
    my @menu;
    while (my ($name) = $st->fetchrow_array) {
        push @menu, $name;
    }
    return \@menu;
}

sub save_menu {
    my ($date, @items) = @_;
    my $db = get_db;
    my $st = $db->prepare("replace into menu (date, position, name) values (?, ?, ?)") or die($db->errstr);
    foreach (0..$#items) {
        $st->execute($date, $_, $items[$_]);
    }
    $db->do("delete from menu where date = ? and position > ?", {}, $date, $#items) or die($db->errstr);
}

sub save_votes {
    my ($date, @votes) = @_;
    my $db = get_db;
    my $st = $db->prepare("insert into votes (date, position, vote, user) values (?, ?, ?, ?)") or die($db->errstr);
    foreach (0..$#votes) {
        $st->execute($date, $_, $votes[$_], "");
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
    my $votes = collect($st, "array", "array", "hash");
    my $max = $db->selectrow_array("select max(position) from votes where date >= date('now', '-1 month')");
    return ($votes, $max);
}

sub new_hash_password {
    return hash_password(token_generator->get, shift);
}

sub hash_password {
    my ($salt, $password) = @_;
    return join(".", $salt, sha1_hex("$salt.$password"));
}

sub create_user {
    my ($email, $password) = @_;
    my $hash = new_hash_password($password);
    my $db = get_db;
    $db->do("insert into users (email, password, created_at) values (?, ?, datetime('now'))", {}, $email, $hash);
    return $db->last_insert_id;
}

sub get_user {
    my ($uid) = @_;
    return get_db->selectrow_hashref("select rowid, email from users where rowid = ? and active > 0", {}, $uid);
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

sub validate_password {
    my ($salted, $password) = @_;
    return 1 unless ($salted);

    my ($salt, $hash) = split /\./, $salted;
    return $salted eq hash_password($salt, $password);
}

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
    $self->stash(user => $user);
    return $user;
};

helper url_match => sub {
    my ($self, $match) = @_;
    $self->req->url->to_rel =~ /^$match/;
};

helper current_user => sub {
    my ($self, $attr) = @_;
    my $user = $self->stash('user');
    return ($user && $attr) ? $user->{$attr} : $user;
};

get '/vote/:date' => sub {
    my $self = shift;
    my $date = $self->param("date");
    $self->stash(menu => get_menu($date));
    return $self->render('vote');
};

post '/vote/:date' => sub {
    my $self = shift;
    my $date = $self->param("date");

    my @votes = map { $self->param($_) } grep /^vote_/, sort $self->param;
    save_votes($date, @votes);

    return $self->redirect_to("/$date");
};

get '/signin' => sub { shift->render('signin'); };

post '/signin' => sub {
    my $self = shift;
    my $user = $self->login($self->param("email"), $self->param('password'));

    unless ($user) {
        $self->flash(type => 'error', message => "Invalid e-email address or password.");
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


get '/edit/:date' => sub {
    my $self = shift;
    my $date = $self->param('date');

    $self->stash(menu => get_menu($date));

    return $self->render('edit');
};

post '/edit/:date' => sub {
    my $self = shift;
    my $date = $self->param('date');

    my @items = map { $self->param($_) || () } grep /name_/, sort $self->param;
    save_menu($date, @items);

    return $self->redirect_to("/edit/$date");
};

get '/profile' => sub { shift->render('profile'); };

post '/profile' => sub {
    my $self = shift;

    my $password = $self->param("password");

    if (!$password) {
        $self->flash(type => "error", message => "Password can't be empty.");
    } elsif ($password eq $self->param("confirm")) {
        change_password($self->current_user->{rowid}, $password);
        $self->flash(type => 'success', message => 'Password was changed.');
    } else {
        $self->flash(type => 'error', message => "Passwords do not match.");
    }
    return $self->redirect_to('/profile');
};

app->secret($ENV{"SESSION_SECRET"} || Session::Token->new->get);
app->start;
