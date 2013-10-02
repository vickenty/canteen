package Canteen::Mail::Helpers;
use 5.14.0;

use Canteen::User qw/make_token/;

sub css_string {
    my $self = shift;
    my $ret = '';
    $ret .= (shift =~ s/_/-/gr) . ':' . shift . ';'
        while (@_);
    return $ret;
}

sub link_to($@) {
    my ($self, $name, $url, $arg) = @_;
    $url = "http://$self->{domain}$url";
    $url .= "/$arg" if ($arg);
    return qq{<a href="$url">$name</a>};
}

sub recipient_token {
    my $self = shift;
    make_token $self->{recipient}, $self->{email_secret};
}

sub helpers {
    qw/
        css_string
        link_to
        recipient_token
    /;
}

1;
