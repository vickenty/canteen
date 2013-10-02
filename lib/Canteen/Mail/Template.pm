package Canteen::Mail::Template;
use Mojo::Template;
use Encode qw/encode_utf8/;

use Canteen::Mail::Helpers;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub render_file {
    my ($self, $file) = @_;
    my $mt = Mojo::Template->new;
    $mt->prepend($self->prepend);
    my $result = $mt->render_file($file, $self->values, $self);
    die $result if ref $result;
    return encode_utf8 $result;
}

sub prepend {
    my $self = shift;

    my $prepend = "no warnings 'redefine';";

    my $vars = join ",", map "\$$_", keys %$self, 'self';
    $prepend .=  "my ($vars) = \@_;";

    $prepend .= "sub $_; *$_ = sub { Canteen::Mail::Helpers::$_(\$self, \@_) };" for (Canteen::Mail::Helpers->helpers);

    return $prepend;
}

sub values {
    values %{$_[0]};
}

sub stash {
    my $self = shift;
    while(@_) {
        my $key = shift;
        $self->{$key} = shift;
    }
}

1;
