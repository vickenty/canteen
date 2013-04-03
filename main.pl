use DBI;
use Mojolicious::Lite;

sub get_db {
    DBI->connect("dbi:SQLite:main.db");
}

get '/' => sub {
    my $self = shift;
    
    return $self->render('vote');
};

app->start;
