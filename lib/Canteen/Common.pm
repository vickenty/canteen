package Canteen::Common;

use strict;
use warnings;

use Exporter::Easy (
    TAGS => [ 
        all => [qw/
            fail
            get_db
            new_hash_password
            hash_password
            validate_password
            collect
            get_token
            today
        /],
    ],
    OK => [ qw/:all/ ],
);

use DBI;
use Digest::SHA qw/sha1_hex/;
use Session::Token;
use POSIX qw/strftime/;

sub fail($) {
    die bless { message => shift }, "Canteen::Error";
}

sub get_token {
    return Session::Token->new->get;
}

sub today {
    return strftime("%Y-%m-%d", localtime);
}

sub new_hash_password {
    return hash_password(get_token, shift);
}

sub hash_password {
    my ($salt, $password) = @_;
    return join(".", $salt, sha1_hex("$salt.$password"));
}

sub validate_password {
    my ($salted, $password) = @_;
    return 1 unless ($salted);

    my ($salt, $hash) = split /\./, $salted;
    return $salted eq hash_password($salt, $password);
}

sub get_db {
    DBI->connect("dbi:SQLite:$ENV{DATABASE}", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
        sqlite_unicode => 1,
    }) or die(DBI->errstr);
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

1;
