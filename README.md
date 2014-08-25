This is a simple service. It runs on the same machine (preferably as the same user) as another that wants to
ingest things into Amazon Glacier. The two communicate via AMQP. Basically the client will send a JSON request
telling what to ingest. This service then takes any necessary initial action, ingests the content, and
returns the archive id to the client.

For now the service is about as simple as it can be to work for our Medusa application.

Configuration
=============

config/amazon.yml contains parameters for interacting with Amazon, including the access key id and secret access
key.

config/amqp.yaml contains parameters for interacting with AMQP, including the queues to use for communication
in each direction.

Running
=======

The medusa_glacier.sh script can be used to start and stop the server. There is also a toggle-halt
command that will let the server finish the request it is working on and then halt (or if used again go cancel this
behavior). This works by sending USR2 to the server, so you can do that manually as well.

Requests
========

A request is a JSON object with three fields:

- action: The action being requested. Currently only 'upload_directory' is supported.
- parameters: Parameters needed for the action.
- pass_through: A JSON object that the server will pass back to the client with its response. The intended use
 is for the client to be able to know what is being responded to.

A response is a JSON object with fields:

- pass_through: Whatever the client originally passed in this field, or nil if absent.
- status: Either 'success' or 'failure'.
- error_message: If the status is failure then this may be returned to give information.
- action: The originally requested action
- parameters: A JSON object with parameters appropriate to the request. For example, on a request for uploading
 a directory we would return the archive id.

Note that for certain errors (e.g. if the request isn't parsable as JSON) it may not be possible to return some
of these things.

upload_directory action:

- Incoming parameters:

  - directory - this is the absolute path to the directory to upload. The server will tar it (putting the tarball
in the same directory that the upload directory is in), upload it, and then delete the tar.
  - description - the text that should go in the description field when uploading to Glacier. The strictly encoded
base64 version of this must be less than 1024 characters (the server will take what it receives and encode it
as base64 using Ruby's standard library Base64.strict_encode64).

And: 

- Outgoing parameters:

  - archive_id - this is the archive id as returned by Amazon Glacier.