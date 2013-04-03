use Mojolicious::Lite;

get '/' => { 'text' => 'Hello world!' };

app->start;
