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
            get_digest_recipients
            make_token
            check_token
            unsubscribe_user
        /],
    ],
    OK => [ qw/:all/ ],
);

use Digest::SHA qw/sha1_hex/;
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
    my ($email, $password, $active, $digest) = @_;
    my $hash = new_hash_password($password);
    $active = $active ? 1 : 0;
    $digest = $digest ? 1 : 0;

    my $db = get_db;
    modify_user sub {
        $db->do("insert into users (email, password, active, digest, created_at) values (?, ?, ?, ?, datetime('now'))",
            {}, $email, $hash, $active, $digest);
    };
}

sub update_user {
    my ($uid, $email, $password, $active, $digest) = @_;
    my $db = get_db;
    $active = $active ? 1 : 0;
    $digest = $digest ? 1 : 0;
    modify_user sub {
        $db->do('update users set email = ?, active = ?, mail_digest = ? where rowid = ?', {}, $email, $active, $digest, $uid);
    };
    if ($password) {
        my $hash = new_hash_password($password);
        $db->do('update users set password = ? where rowid = ?', {}, $hash, $uid);
    }
}

sub list_users {
    return get_db->selectall_arrayref("select rowid, email, last_login_at, active, mail_digest, created_at from users", { Slice => {} });
}

sub get_user {
    my ($uid) = @_;
    return get_db->selectrow_hashref("select rowid, email, active, mail_digest from users where rowid = ?", {}, $uid);
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

sub get_digest_recipients {
    return get_db->selectall_arrayref("select rowid, email from users where active > 0 and mail_digest > 0", { Slice => {} });
}

sub make_token {
    my ($user, $secret, $time) = @_;
    $time //= time;
    return join '.', sha1_hex(join '.', $time, $user->{email}, $secret), $user->{rowid}, $time;
}

sub check_token {
    my ($token, $secret) = @_;

    my (undef, $uid, $time) = split /\./, $token;
    return unless $uid && $time;

    my $user = get_user $uid;
    return unless $user;

    my $true = make_token $user, $secret, $time;

    return $true eq $token && $user;
}

sub unsubscribe_user {
    my $uid = shift;
    get_db->do("update users set mail_digest = 0 where rowid = ?", {}, $uid);
}

1;
