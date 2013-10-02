#!/usr/bin/env perl
use strict;
use warnings;

use DateTime;
use Getopt::Long;
use Email::MIME::CreateHTML;
use Email::Sender::Simple qw/sendmail/;

use Canteen::Common qw/:all/;
use Canteen::Menu qw/:all/;
use Canteen::User qw/get_digest_recipients/;
use Canteen::Mail::Template;
use Data::Dumper;

sub send_it {
    my ($recipient, $subject, $html, $text) = @_;
    my $message = Email::MIME->create_html(
        header => [
            From => get_env("SENDER"),
            To => $recipient,
            Subject => $subject,
        ],
        body => $html,
        text_body => $text,
    );

    sendmail $message;
}

sub get_env {
    $ENV{$_[0]} or die "Missing $_[0] environment variable";
}

sub main {
    my $offset = 0;
    GetOptions('offset=i' => \$offset) or die "Failed to parse command-line options\n";

    my $date = DateTime->now;
    $date->add(days => $offset) if $offset;

    my $votes = get_votes($date->ymd('-'));

    my $render = Canteen::Mail::Template->new(
        date => $date,
        votes => $votes,
        domain => get_env('DOMAIN'),
        email_secret => get_env('EMAIL_SECRET'),
    );

    my $recipients = get_digest_recipients;
    foreach my $recipient (@$recipients) {
        $render->stash(
            recipient => $recipient,
        );

        my $subj = $render->render_file('templates/mail/votes.subj.ep');
        my $html = $render->render_file('templates/mail/votes.html.ep');
        my $text = $render->render_file('templates/mail/votes.text.ep');

        send_it $recipient->{email}, $subj, $html, $text;
    }
}

main;
