# NAME

OpenAPI::Client - A client for talking to an Open API powered server

# DESCRIPTION

[OpenAPI::Client](https://metacpan.org/pod/OpenAPI%3A%3AClient) generates objects that can talk to Open API servers.
For each fresh OpenAPI contract given to the ["new"](#new) method, a custom subclass
is created from the Open API specification, with methods corresponding
to the operationIds. Parameters received by these methods are transformed
into HTTP requests. Input validation is performed, so invalid data won't be
sent to the server.

Note that this implementation is currently EXPERIMENTAL, but unlikely to change!
Feedback is appreciated.

# SYNOPSIS

## Creating a client

    use OpenAPI::Client;
    $client = OpenAPI::Client->new("file:///path/to/api.json");

The specification given to ["new"](#new) must point to a valid OpenAPI document.
Several syntax variants are admitted -- see the ["new"](#new) method.

## Open API specification

The OpenAPI document can be in OpenAPI version v2.x or v3.x, and it can be in either JSON or YAML
format. Example:

    openapi: 3.0.1
    info:
      title: Swagger Petstore
      version: 1.0.0
    servers:
    - url: http://petstore.swagger.io/v1
    paths:
      /pets:
        get:
          operationId: listPets
          ...

The url specified in the OpenAPI document can be altered at any time, if you need to send data to another
custom endpoint -- see the ["base\_url"](#base_url) method.

## Client

The OpenAPI API specification will be used to generate a sub-class of
[OpenAPI::Client](https://metacpan.org/pod/OpenAPI%3A%3AClient) with additional methods corresponding to "operationId" inside of each path definition :

    # Blocking
    $tx = $client->listPets;

    # Non-blocking
    $client = $client->listPets(sub { my ($client, $tx) = @_; });

    # Promises
    $promise = $client->listPets_p->then(sub { my $tx = shift });

    # With parameters
    $tx = $client->listPets({limit => 10});

See [Mojo::Transaction](https://metacpan.org/pod/Mojo%3A%3ATransaction) for more information about what you can do with the
`$tx` object. Often you just want something like this:

    # Check for errors
    die $tx->error->{message} if $tx->error;

    # Extract data from the JSON responses
    say $tx->res->json->{pets}[0]{name};

Check out ["error" in Mojo::Transaction](https://metacpan.org/pod/Mojo%3A%3ATransaction#error), ["req" in Mojo::Transaction](https://metacpan.org/pod/Mojo%3A%3ATransaction#req) and
["res" in Mojo::Transaction](https://metacpan.org/pod/Mojo%3A%3ATransaction#res) for some of the most used methods in that class.

# CUSTOMIZATION

## Custom server URL

If you want to request another server than the one specified in the Open
API document, you can change the ["base\_url"](#base_url):

    # Pass on a Mojo::URL object to the constructor
    $base_url = Mojo::URL->new("http://example.com");
    $client1 = OpenAPI::Client->new("file:///path/to/api.json", base_url => $base_url);

    # A plain string will be converted to a Mojo::URL object
    $client2 = OpenAPI::Client->new("file:///path/to/api.json", base_url => "http://example.com");

    # Change the base_url after the client has been created
    $client3 = OpenAPI::Client->new("file:///path/to/api.json");
    $client3->base_url->host("other.example.com");

## Custom content

You can send XML or any format you like, but this requires you to add a new
"generator":

    use Your::XML::Library "to_xml";
    $client->ua->transactor->add_generator(xml => sub {
      my ($t, $tx, $data) = @_;
      $tx->req->body(to_xml $data);
      return $tx;
    });

    $client->addHero({}, xml => {name => "Supergirl"});

See [Mojo::UserAgent::Transactor](https://metacpan.org/pod/Mojo%3A%3AUserAgent%3A%3ATransactor) for more details.

# EVENTS

## after\_build\_tx

    $client->on(after_build_tx => sub { my ($client, $tx) = @_ })

This event is emitted after a [Mojo::UserAgent::Transactor](https://metacpan.org/pod/Mojo%3A%3AUserAgent%3A%3ATransactor) object has been
built, just before it is passed on to the ["ua"](#ua). Note that all validation has
already been run, so altering the `$tx` too much might cause an invalid
request on the server side.

A special ["env" in Mojo::Message::Request](https://metacpan.org/pod/Mojo%3A%3AMessage%3A%3ARequest#env) variable will be set, to reference the
operationId:

    $tx->req->env->{operationId};

Note that this usage of `env()` is currently EXPERIMENTAL:

# ATTRIBUTES

## base\_url

    $base_url = $client->base_url;

Returns a [Mojo::URL](https://metacpan.org/pod/Mojo%3A%3AURL) object with the base URL to the API. The default value
comes from `schemes`, `basePath` and `host` in the OpenAPI v2 specification
or from `servers` in the OpenAPI v3 specification.

## ua

    $ua = $client->ua;

Returns a [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent) object which is used to execute requests.

# CLASS METHODS

## new

    $client = OpenAPI::Client->new($specification, \%attributes);
    $client = OpenAPI::Client->new($specification, %attributes);

Returns an object of a dynamic subclass of `OpenAPI::Client`, 
with methods generated from the OpenAPI specification located at `$specification`. 
Such subclasses are cached, so several invocations of `new()` with the same
`$specification` URL will result in several instances of the same subclass.

The `$specification` argument can accept various syntaxes -- see ["schema" in JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator#schema).

Extra `%attributes` can be:

- app

    Can be used to run against a local [Mojolicious](https://metacpan.org/pod/Mojolicious) instance instead of issuing real
    HTTP calls to a remote server.

- coerce

    See ["coerce" in JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator#coerce). Default to "booleans,numbers,strings".

# INSTANCE METHODS

## call

    $tx = $client->call($operationId => \%params, %content);
    $client = $client->call($operationId => \%params, %content, sub { my ($client, $tx) = @_; });

Used to call an `$operationId` that is not a proper Perl method name, such as
"list pets" instead of "listPets", or to check if an `$operationId` is supported.
Unsupported operationIds throw an exception matching text "No such operationId".

`$operationId` is the name of the resource defined in the
[OpenAPI specification](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#operation-object).

`$params` is optional, but must be a hash ref, where the keys should match a
named parameter in the [OpenAPI specification](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#parameter-object).

`%content` is used for the body of the request, where the key needs to be
either "body" or a matching ["generators" in Mojo::UserAgent::Transactor](https://metacpan.org/pod/Mojo%3A%3AUserAgent%3A%3ATransactor#generators). Example:

    $client->addHero({}, body => "Some data");
    $client->addHero({}, json => {name => "Supergirl"});

Like in [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent), an additional coderef argument can be supplied in last position.
In that case the call is asynchronous, and the coderef will be called as a continuation
callback, with two arguments `$client` (the current openAPI client) and `$tx`
(a [Mojo::Transaction](https://metacpan.org/pod/Mojo%3A%3ATransaction) object). See ["Non-blocking" in Mojolicious::Guides::Cookbook](https://metacpan.org/pod/Mojolicious%3A%3AGuides%3A%3ACookbook#Non-blocking) for details.

## call\_p

    $promise = $client->call_p($operationId => $params, %content);
    $promise->then(sub { my $tx = shift });

As ["call"](#call) above, but returns a [Mojo::Promise](https://metacpan.org/pod/Mojo%3A%3APromise) object.

## validator

    $validator = $client->validator;
    $validator = $class->validator;

Returns the [JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema) object associated with the current generated class.
Depending on the openAPI specification, this object will belong to the
[OpenAPIv2](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3AOpenAPIv2) or
[OpenAPIv3](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3AOpenAPIv3) subclass.
This object global to the class, so changing it will affect all instances returned by ["new"](#new).

# COPYRIGHT AND LICENSE

Copyright (C) 2017-2021, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

# AUTHORS

## Project Founder

Jan Henning Thorsen - `jhthorsen@cpan.org`

## Contributors

- Clive Holloway <clhollow@estee.com>
- Ed J <mohawk2@users.noreply.github.com>
- Jan Henning Thorsen <jan.henning@thorsen.pm>
- Jan Henning Thorsen <jhthorsen@cpan.org>
- Mohammad S Anwar <mohammad.anwar@yahoo.com>
- Reneeb <info@perl-services.de>
- Roy Storey <kiwiroy@users.noreply.github.com>
- Veesh Goldman <rabbiveesh@gmail.com>
- Laurent Dami <dami@cpan.org>
