package Mojolicious::Command::openapi;
use Mojo::Base 'Mojolicious::Command';

use OpenAPI::Client;
use Mojo::JSON qw(encode_json decode_json j);
use Mojo::Util qw(encode getopt);

has description => 'Perform Open API requests';
has usage => sub { shift->extract_usage . "\n" };

sub run {
  my ($self, @args) = @_;
  my %ua;

  getopt \@args,
    'i|inactivity-timeout=i' => sub { $ua{inactivity_timeout} = $_[1] },
    'o|connect-timeout=i'    => sub { $ua{connect_timeout}    = $_[1] },
    'S|response-size=i'      => sub { $ua{max_response_size}  = $_[1] },
    'v|verbose'              => \my $verbose;

  my $specification = ($args[0] and -e $args[0]) ? shift @args : $ENV{OPENAPI_SPECIFICATION};
  my $operation     = shift @args;
  my $params        = ($args[0] and $args[0] =~ /^\{/) ? shift @args : '{}';
  my $selector      = shift @args // '';
  my ($client, $tx, $charset);

  die $self->usage unless $specification;

  $client = OpenAPI::Client->new($specification);
  return say "$specification is valid." unless $operation;

  $client->ua->proxy->detect unless $ENV{OPENAPI_NO_PROXY};
  $client->ua->$_($ua{$_}) for keys %ua;

  $client->ua->on(
    start => sub {
      my ($ua, $tx) = @_;
      weaken $tx;
      $tx->res->content->on(body => sub { warn _header($tx->req), _header($tx->res) }) if $verbose;
    }
  );

  $tx = $client->$operation(decode_json $params);

  if ($tx->error and $tx->error->{message} eq 'Invalid input') {
    warn _header($tx->req), _header($tx->res) if $verbose;
  }

  return _json($tx->res->json, $selector) if !length $selector || $selector =~ m!^/!;
  return _say($tx->res->dom->find($selector)->each);
}

sub _header { $_[0]->build_start_line, $_[0]->headers->to_string, "\n\n" }

sub _json {
  return unless defined(my $data = Mojo::JSON::Pointer->new(shift)->get(shift));
  return _say($data) unless ref $data eq 'HASH' || ref $data eq 'ARRAY';
  say encode_json($data);
}

sub _say { length && say encode('UTF-8', $_) for @_ }

1;

=encoding utf8

=head1 NAME

Mojolicious::Command::openapi - Perform Open API requests

=head1 SYNOPSIS

  Usage: APPLICATION openapi SPECIFICATION OPERATION "{ARGUMENTS}" [SELECTOR|JSON-POINTER]

    ./myapp.pl openapi spec.json
    ./myapp.pl openapi spec.json listPets
    ./myapp.pl openapi spec.json listPets /pets/0
    ./myapp.pl openapi spec.json addPet '{"name":"pluto"}'
    mojo openapi http://service.example.com/api.json listPets

  Options:
    -h, --help                           Show this summary of available options
    -i, --inactivity-timeout <seconds>   Inactivity timeout, defaults to the
                                         value of MOJO_INACTIVITY_TIMEOUT or 20
    -o, --connect-timeout <seconds>      Connect timeout, defaults to the value
                                         of MOJO_CONNECT_TIMEOUT or 10
    -S, --response-size <size>           Maximum response size in bytes,
                                         defaults to 2147483648 (2GB)
    -v, --verbose                        Print request and response headers to
                                         STDERR

=head1 DESCRIPTION

L<Mojolicious::Command::openapi> is a command line interface for
L<OpenAPI::Client>.

=head1 ATTRIBUTES

=head2 description

  $str = $self->description;

=head2 usage

  $str = $self->description;

=head1 METHODS

=head2 run

  $get->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<OpenAPI::Client>.

=cut
