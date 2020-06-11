use Mojo::Base -strict;
use OpenAPI::Client;
use Test::More;
use Mojo::JSON 'true';

my $client = OpenAPI::Client->new('data://main/test.json');

ok 1;

{
  my @errors = $client->openapi_validate_loginUser;
  is $errors[0]->message => "Missing property.";
  is $errors[0]->path    => "/body";
}

{
  my @errors = $client->openapi_validate_loginUser({body => {email => 'superman@example.com'}});
  is $errors[0]->message => "Missing property.";
  is $errors[0]->path    => "/body/password";
}

{
  my @errors = $client->openapi_validate_loginUser({body => {email => 'superman@example.com', password => 's3cret'}});
  ok !@errors;
}

done_testing;

__DATA__
@@ test.json
{
  "swagger": "2.0",
  "info": { "version": "0.8", "title": "Test client spec" },
  "schemes": [ "http" ],
  "host": "api.example.com",
  "basePath": "/v1",
  "paths": {
    "/user/login": {
      "post": {
        "tags": [ "user" ],
        "summary": "Log in a user based on email and password.",
        "operationId": "loginUser",
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": {
              "type": "object",
              "required": ["email", "password"],
              "properties": {
                "email": { "type": "string", "format": "email", "description": "User email" },
                "password": { "type": "string", "description": "User password" }
              }
            }
          }
        ],
        "responses": {
          "200": {
            "description": "User profile.",
            "schema": { "type": "object" }
          }
        }
      }
    }
  }
}
