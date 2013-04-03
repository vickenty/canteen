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
    foreach (0..5) {
        $st->execute($date, $_, $items[$_]);
    }
}

sub save_votes {
    my ($date, @votes) = @_;
    my $db = get_db;
    my $st = $db->prepare("insert into votes (date, position, vote, user) values (?, ?, ?, ?)") or die($db->errstr);
    foreach (0..5) {
        $st->execute($date, $_, $votes[$_], "");
    }
};

get '/:date' => sub {
    my $self = shift;
    my $date = $self->param("date");
    $self->stash(menu => get_menu($date));
    return $self->render('vote');
};

post '/:date' => sub {
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

    my @items = map { $self->param($_) } grep /name_/, $self->param;
    save_menu($date, @items);

    return $self->redirect_to("/edit/$date");
};

app->start;
