This is a simple service. It runs on the same machine (preferably as the same user) as another that wants to
ingest things into Amazon Glacier. The two communicate via AMQP. Basically the client will send a JSON request
telling what to ingest. This service then takes any necessary initial action, ingests the content, and
returns the archive ids to the client. 

In contrast to earlier versions of this service the client now is not responsible for figuring out what files to
send and splitting up into chunks if the directory is too large. Instead the client will pass a date to use
to filter files for upload and this server will use it to filter. Also this server will (eventually) be responsible
for splitting up the content if that is necessary, although for now we assume that all of our bags will fall under
Amazon's 40TB limit.

For now the service is about as simple as it can be to work for our Medusa application.

Configuration
=============

All configuration is specified in glacier_server.yaml.

The server stanza must have an (arbitrary) name for the server. It optionally takes a value
for allow_deletion (by default false). 

The amqp section specifies all information necessary to connect to the amqp server
as well as the incoming and outgoing queues.

The amazon section specifies the information necessary to connect to Amazon Glacier
itself.

The cfs section specifies where the content root is (so relative paths start
here) and where to make the tars for backup.

Running
=======

The medusa_glacier.sh script can be used to start and stop the server. There is also a toggle-halt
command that will let the server finish the request it is working on and then halt (or if used again go cancel this
behavior). This works by sending USR2 to the server, so you can do that manually as well.

Requests
========

A request is a JSON object with three fields:

- action: The action being requested. Currently only 'upload_directory' and 'delete_archive' are supported.
- parameters: Parameters needed for the action.
- pass_through: A JSON object that the server will pass back to the client with its response. The intended use
 is for the client to be able to know what is being responded to.

A response is a JSON object with fields:

- pass_through: Whatever the client originally passed in this field, or nil if absent.
- status: Either 'success' or 'failure'.
- error_message: If the status is failure then this may be returned to give information.
- action: The originally requested action
- parameters: A JSON object with parameters appropriate to the request. For example, on a request for uploading
 a directory we would return the archive ids.

Note that for certain errors (e.g. if the request isn't parseable as JSON) it may not be possible to return some
of these things.

upload_directory action:

- Incoming parameters:

  - directory - this is the path relative to the cfs root to be uploaded. The server will tar it, upload it, 
and then delete the tar.
  - description - the text that should go in the description field when uploading to Glacier. The strictly encoded
base64 version of this must be less than 1024 characters (the server will take what it receives and encode it
as base64 using Ruby's standard library Base64.strict_encode64).
  - date (optional) - if this is present and represents a date then only files with mtime equal to or later than the
   given date will be uploaded. Otherwise (if absent or null) all files will be.

And: 

- Outgoing parameters:

  - archive_ids - these are the archive ids as returned by Amazon Glacier, in a JSON array. Note that at present
we only handle directories that are small enough to fit into a single amazon upload, about 40TB (a little less in
practice because of the tar overhead), so this will always have one element only.

delete_archive action:

- Incoming parameters:

  - archive_id - the Amazon Glacier archive id to be deleted
  
And:

- Outgoing parameters: 

  - archive_id - the deleted archive id

