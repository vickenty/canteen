package Canteen::User;
use strict;
use warnings;

use Exporter::Easy (
    TAGS => [ 
        all => [qw/
            create_user
            update_user
            list_users
            get_user
            get_user_by_email
            record_login
            change_password
        /],
    ],
    OK => [ qw/:all/ ],
);

use Canteen::Common qw/:all/;

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
    my $db = get_db();
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

1;
