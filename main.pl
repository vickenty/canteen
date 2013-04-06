use DBI;
use Mojolicious::Lite;

plugin 'DefaultHelpers';

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

get '/view' => sub {
    my $self = shift;
    my ($votes, $max_items) = get_recent_votes();
    $self->stash(
        votes => $votes,
        max_items => $max_items
    );
    return $self->render('view');
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

app->start;
