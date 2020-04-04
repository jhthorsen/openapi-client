use Mojo::Base -strict;
use Mojo::JSON 'true';
use OpenAPI::Client;
use Test::More;

use Mojolicious::Lite;
app->log->level('error') unless $ENV{HARNESS_IS_VERBOSE};

my $i = 0;
get '/pets/:type' => sub {
  $i++;
  my $c = shift->openapi->valid_input or return;
  $c->render(openapi => [{type => $c->param('type')}]);
  },
  'listPetsByType';

get '/pets' => sub {
  my $c = shift->openapi->valid_input or return;
  $c->render(openapi => [$c->req->params->to_hash]);
  },
  'list pets';

post '/pets' => sub {
  my $c   = shift->openapi->valid_input or return;
  my $res = $c->req->body_params->to_hash;
  $res->{dummy} = true if $c->req->headers->header('x-dummy');
  $c->render(openapi => $res);
  },
  'addPet';

plugin OpenAPI => {url => 'data://main/test.json', schema => 'v3'};

is(OpenAPI::Client->new('data://main/test.json', schema => 'v3')->base_url,       'http://api.example.com:3000/v1', 'base_url');
is(OpenAPI::Client->new('data://main/test.json', schema => 'v3')->base_url->host, 'api.example.com',                'base_url host');
is(OpenAPI::Client->new('data://main/test.json', schema => 'v3')->base_url->port, '3000',                           'base_url port');

my $client = OpenAPI::Client->new('data://main/test.json', app => app, schema => 'v3');
my ($obj, $tx);

is +ref($client), 'OpenAPI::Client::main_test_json', 'generated class';
isa_ok($client, 'OpenAPI::Client');
can_ok($client, 'addPet');

note 'Sync testing';
$tx = $client->listPetsByType;
is $tx->res->code, 400, 'sync invalid listPetsByType';
is $tx->error->{message}, 'Invalid input', 'sync invalid message';
is $i, 0, 'invalid on client side';

$tx = $client->listPetsByType({type => 'dog', p => 12});

is $tx->res->code, 200, 'sync listPetsByType';
is $tx->req->url->query->param('p'), 12, 'sync listPetsByType p=12';
is $i, 1, 'one request';

$tx = $client->addPet({age => '5', type => 'dog', name => 'Pluto', 'x-dummy' => true});
is $tx->res->code, 200, 'coercion for "age":"5" works';

$tx = $client->addPet({age => '5', type => 'dog', 'x-dummy' => true});
is $tx->res->code, 400, 'missing required name addPet';
is $tx->error->{message}, 'Invalid input', 'sync invalid message';

note 'Async testing';
$i = 0;
is $client->listPetsByType(sub { ($obj, $tx) = @_; Mojo::IOLoop->stop }), $client, 'async request';
Mojo::IOLoop->start;
is $obj, $client, 'got client in callback';
is $tx->res->code, 400, 'invalid listPetsByType';
is $tx->error->{message}, 'Invalid input', 'sync invalid message';
is $i, 0, 'invalid on client side';

note 'Promise testing';
my $p = $client->listPetsByType_p->then(sub { $tx = shift });
$tx = undef;
$p->wait;
is $tx->res->code, 400, 'invalid listPetsByType';
is $tx->error->{message}, 'Invalid input', 'sync invalid message';
is $i, 0, 'invalid on client side';

note 'call()';
$tx = $client->call('list pets', {page => 2});
is_deeply $tx->res->json, [{page => 2}], 'call(list pets)';

eval { $tx = $client->call('nope') };
like $@, qr{No such operationId.*client_v3\.t}, 'call(nope)';

# this approach from https://metacpan.org/source/SRI/Mojolicious-7.59/t/mojo/promise.t and user_agent.t
note 'call_p()';
my $promise = $client->call_p('list pets', {page => 2});
my (@results, @errors);
$promise->then(sub { @results = @_ }, sub { @errors = @_ });
$promise->wait;
is_deeply $results[0]->res->json, [{page => 2}], 'call_p(list pets)';
is_deeply \@errors, [], 'promise not rejected';

note 'call_p() rejecting';
$promise = $client->call_p('list all pets', {page => 2});
(@results, @errors) = ();
$promise->then(sub { @results = @_ }, sub { @errors = @_ });
$promise->wait;
is_deeply \@results, [], 'call_p(list all pets) does not exist';
is_deeply \@errors, ['[OpenAPI::Client] No such operationId'], 'promise got rejected';

note 'boolean';
my $err;
$client->listPetsByType_p({type => 'cat', is_cool => true})->then(sub { $tx = shift }, sub { $err = shift })->wait;
is $tx->res->code, 200, 'accepted is_cool=true';
is $tx->req->url->query->to_string, 'is_cool=1', 'is_cool in query parameter';

done_testing;

__DATA__
@@ test.json
{
  "openapi": "3.0.0",
  "info": {
    "version": "0.8",
    "title": "Test client spec"
  },
  "paths": {
    "x-whatever": [],
    "/pets": {
      "x-whatever": [],
      "parameters": [],
      "get": {
        "operationId": "list pets",
        "parameters": [
          {
            "in": "query",
            "name": "page",
            "schema": {
              "type": "integer"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "pets",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {}
                }
              }
            }
          }
        }
      },
      "post": {
        "x-whatever": [],
        "operationId": "addPet",
        "parameters": [
          {
            "in": "header",
            "name": "x-dummy",
            "schema": {
              "type": "boolean"
            }
          }
        ],
        "requestBody": {
          "content": {
            "application/x-www-form-urlencoded": {
              "schema": {
                "type": "object",
                "required": [
                  "name"
                ],
                "properties": {
                  "name": {
                    "type": "string"
                  },
                  "age": {
                    "type": "integer"
                  },
                  "type": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "pet response",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object"
                }
              }
            }
          }
        }
      }
    },
    "/pets/{type}": {
      "get": {
        "operationId": "listPetsByType",
        "parameters": [
          {
            "in": "query",
            "name": "is_cool",
            "schema": {
              "type": "boolean"
            }
          },
          {
            "in": "path",
            "name": "type",
            "required": true,
            "schema": {
              "type": "string"
            }
          },
          {
            "$ref": "#/components/parameters/p"
          }
        ],
        "responses": {
          "200": {
            "description": "pet response",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ok"
                }
              }
            }
          }
        }
      }
    }
  },
  "servers": [
    {
      "url": "http://api.example.com:3000/v1"
    }
  ],
  "components": {
    "parameters": {
      "p": {
        "in": "query",
        "name": "p",
        "schema": {
          "type": "integer"
        }
      }
    },
    "schemas": {
      "ok": {
        "type": "array",
        "items": {}
      }
    }
  }
}