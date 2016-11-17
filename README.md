# RNSync

[![Join the chat at https://gitter.im/pwcremin/rnsync](https://badges.gitter.im/pwcremin/rnsync.svg)](https://gitter.im/pwcremin/rnsync?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## About

RNSync is a React Native module that allows you to work with your Cloudant or CouchDB database locally (on the mobile device) and replicate to the remote database when needed.

RNSync is a wrapper for [Cloudant Sync](https://github.com/cloudant/CDTDatastore), which simplifies large-scale mobile development by enabling you to create a single database for every user; you simply replicate and sync the copy of this database in Cloudant with a local copy on their phone or tablet. This can reduce round-trip database requests with the server. If there’s no network connection, the app runs off the database on the device; when the network connection is restored, Cloudant re-syncs the device and server.

Sign up for [Bluemix](http://bit.ly/2fYtrCz) and you can get your own instance of [Cloudant](http://bit.ly/2eH8lbY) (where a free tier is available).

## Installation

Install with npm
```ruby
npm install --save rnsync
```

### iOS

Edit your Podfile (find help with setting up CocoaPods [here](https://guides.cocoapods.org/using/using-cocoapods.html). Hint: its easy)
```ruby
pod 'rnsync', :path => '../node_modules/rnsync/ios'
```

Pod install
```ruby
pod install
```
### Android

```ruby
react-native link rnsync
```

## Udates
 * 11/16 - 
   * Added Android support
   * Both pull and push replication are now supported (the replicate function has been replaced with replicatePull and replicatePush)
   * Removed 'addAttachment' until its functionality is fully implemented
 * 3/28 - all functions now return promises
 * 3/28 - init() will no longer create the database for you.  Please refer to cloudantApiKeyGenerator/app.js for an example of how to securely create the database and get your api keys (for Cloudant)
 
## Usage

#### Init

The below example exposes your credentials on every device, and the database must already exist, but it is fine for testing the package. 

To avoid exposing credentials create a web service to authenticate users and set up databases for client devices. This web service needs to:

- Handle sign in/sign up for users.
- Create a new remote database for a new user.
- Grant access to the new database for the new device (e.g., via [API keys on Cloudant](https://cloudant.com/for-developers/faq/auth/) or the _users database in CouchDB).
- Return the database URL and credentials to the device.

Please refer to cloudantApiKeyGenerator/app.js for an example of how to securely create the database and get your api keys (for Cloudant)
 
```javascript
var rnsync = require('rnsync');

// init with your cloudant or couchDB database
var dbUrl = "https://user:pass@xxxxx";
var dbName = "name_xxxx";

rnsync.init(dbUrl, dbName, function(error)
{
  console.log(error);
}
```

#### Create

Both the object and the id are optional.  If you leave out the object it will create a new doc that is empty.  If you leave
out the id that will be autogenerated for you.
```javascript
var object = {x:10};
var id = "whatever";

rnsync.create(object, id, function(error, doc)
{
  console.log(doc.id);
}

rnsync.create({name: 'jon'},  function(error, doc)
{
  console.log(doc.id);
}

// note: create will return an error if the id already exist
rnsync.create('user',  function(error, doc)
{
  console.log(doc.id);
}

```

#### Find or Create

Returns the doc with the specified id.  It will create the doc if it does not already exist.

```javascript
rnsync.findOrCreate('user',  function(error, doc)
{
  console.log(doc.id);
}
```

#### Retrieve

Returns the doc with the specified id.

```javascript

var id = "whatever";

rnsync.retrieve(id, function(error, doc)
{
  console.log(JSON.stringify(doc.body));
}
```

#### Update

When doing an update to a doc, you must include the revision.

```javascript

doc.body.somechange = "hi mom";

rnsync.update(doc.id, doc.rev, doc.body, function(error, doc)
{
  console.log(JSON.stringify(doc.body));
}
```

#### Delete

```javascript

rnsync.delete(doc.id, function(error)
{
  console.log(error);
}
```

#### Replicate

All of the CRUD functions only affect the local database.  To push your changes to the remote server you must replicate.  For more details see the [replication docs](https://github.com/cloudant/CDTDatastore/blob/master/doc/replication.md)

Push your local changes to the remote database
```javascript
rnsync.replicatePush( error => console.log(error) );
```

Pull changes from the remote database to your local
```javascript
rnsync.replicatePull( error => console.log(error) );
```

#### Find

Query for documents.  For more details on the query semantics please see the [Cloudant query documentation](https://github.com/cloudant/CDTDatastore/blob/master/doc/query.md)

```javascript
var query = {name: 'John', age: { '$gt': 25 }};

rnsync.find(query, function(docs)
{
  console.log('found ' + docs.length);
});
```
## Known Issues
- Calling replicate() before a previous replication has completed will error.  Caused by overwritting sucess/fail callbacks

## Author

Patrick Cremin, pwcremin@gmail.com

## License

RNSync is available under the MIT license. See the LICENSE file for more info.
