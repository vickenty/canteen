package Canteen::Menu;
use strict;
use warnings;

use Exporter::Easy (
    TAGS => [
        all => [ qw/
            get_menu
            save_menu
            save_votes
            get_votes
            get_recent_votes
            get_menu_dates
        /],
    ],
    OK => [ qw/:all/ ],
);

use DateTime;
use Canteen::Common qw/get_db collect/;

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

sub get_recent_votes {
    my $db = get_db;
    my $st = $db->prepare(q{
        select
            date, name, vote, count(*) votes
        from votes
        join menu using (date, position)
        where date >= date('now', '-1 month')
        group by date, position, vote
    });
    $st->execute;
    my $votes = collect($st, "array", "array", "hash");
    return $votes;
}

sub get_votes {
    my $date = shift;
    my $db = get_db;
    my $st = $db->prepare(q{
        select
            name, vote, count(*) votes
        from votes
        join menu using (date, position)
        where date = ?
        group by name, vote
    });
    $st->execute($date);
    return collect($st, "array", "hash");
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

1;
