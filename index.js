var rnsyncModule = require( 'react-native' ).NativeModules.RNSync;
import {Platform} from 'react-native';

const noop = () =>
{
};

class RNSyncStorage {

  setItem ( key, value, databaseName, callback )
  {
    callback = callback || noop;

    // value is a string, but we need a data blob
    let body = { value }

    rnsyncModule.retrieve( key, databaseName, ( error, doc ) =>
    {
      if(error)     // should be 404
      {
        rnsyncModule.create( body, key, databaseName, callback );
      }
      else
      {
        rnsyncModule.update( doc.id, doc.key, body, databaseName, callback );
      }
    } );
  }

  getItem ( key, databaseName, callback )
  {
    callback = callback || noop;

    rnsyncModule.retrieve( key, databaseName, ( error, doc ) =>
    {
      let item = error ? null : doc.body.value;

      callback(error, item);
    } );

  }

  removeItem ( key, databaseName, callback )
  {
    callback = callback || noop;

    rnsyncModule.delete( key, databaseName, callback );
  }

  getAllKeys ( databaseName, callback )
  {
    callback = callback || noop;

    // using _id as the field isn't right (since the body doesn't contain an _id) but
    // it keeps the body from returning since the field doesn't exist
    // TODO try ' '?
    rnsyncModule.find( {'_id': {'$exists': true } }, ['_id'], databaseName, ( error, docs ) =>
    {
      if(error)
      {
        callback(error);
        return;
      }

      if ( Platform.OS === "android" )
      {
        docs = docs.map( doc => JSON.parse( doc ) )
      }

      let keys = docs.map( doc => {
        return doc.id
      })

      callback( null, keys );
    } );
  }

  deleteAllKeys( databaseName, callback )
  {
    this.getAllKeys( databaseName, (error, keys ) =>
    {
      if(error)
      {
        callback(error)
      }
      else
      {
        for (let i = 0; i < keys.length; i++) {
          let key = keys[i];
          this.removeItem(key, databaseName)
        }

        callback(null)
      }

    })
  }
}

class RNSyncWrapper
{
  // TODO specify the name of the local datastore
  init ( cloudantServerUrl, databaseName, callback )
  {
    callback = callback || noop;

    return new Promise( ( resolve, reject ) =>
    {
      var databaseUrl = cloudantServerUrl + '/' + databaseName;

      rnsyncModule.init( databaseUrl, databaseName, error =>
      {
        callback( error );
        if(error) reject(error);
        else resolve()
      } );
    } )
  }

  create ( body, id, databaseName, callback )
  {
    callback = callback || noop;

    if ( typeof(body) === 'string' && typeof(id) === 'function')
    {
      callback = id;

      id = body;databaseName

      body = null;
    }
    else if ( typeof(body) === 'function' )
    {
      callback = body;

      body = id = null;
    }

    if ( typeof(id) === 'function' )
    {
      callback = id;

      id = null;
    }

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.create( body, id, databaseName, ( error, doc ) =>
      {
        callback( error, doc );
        if(error) reject(error);
        else resolve(doc)
      } );
    })
  }

  retrieve ( id, databaseName, callback )
  {
    callback = callback || noop;

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.retrieve( id, databaseName, ( error, doc ) =>
      {
        callback( error, doc );
        if(error) reject(error);
        else resolve(doc)
      } );
    })
  }

  // This will pass in the callback the base64 encoded version of the attachement
  retrieveFirstAttachmentFor ( id, databaseName, callback )
  {
    callback = callback || noop;

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.retrieveFirstAttachmentFor( id, databaseName, ( error, data ) =>
      {
        callback( error, data );
        if(error) reject(error);
        else resolve(data)
      } );
    })
  }

  findOrCreate ( id, databaseName, callback )
  {
    callback = callback || noop;

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.retrieve( id, databaseName, ( error, doc ) =>
      {
        if ( error === 404 )
        {
          this.create( null, id, databaseName, (error, doc) =>
          {
            callback( error, doc );
            if(error) reject(error);
            else resolve(doc)
          })
        }
        else
        {
          callback( error, doc );
          if(error) reject(error);
          else resolve(doc)
        }
      });
    })
  }

  update ( id, rev, body, databaseName, callback )
  {
    callback = callback || noop;

    if ( typeof(id) === 'object' )
    {
      var doc = id;
      id = doc.id;
      rev = doc.rev;
      body = doc.body;
    }

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.update( id, rev, body, databaseName, ( error, doc ) =>
      {
        callback( error, doc );
        if(error) reject(error);
        else resolve(doc)
      } );
    })
  }

  delete ( id, databaseName, callback )
  {
    callback = callback || noop;

    if ( typeof(id) === 'object' )
    {
      id = id.id; // doc.id
    }

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.delete( id, databaseName, ( error ) =>
      {
        callback( error );
        if(error) reject(error);
        else resolve()
      } );
    });

  }

  replicateSync( databaseName, callback )
  {
    callback = callback || noop;

    var pushPromise = this.replicatePush(databaseName);
    var pullPromise = this.replicatePull(databaseName);

    return Promise.all([pushPromise, pullPromise])
      .then(callback)
      .catch( e => {
        callback(e);
        throw(e);
      })
  }

  replicatePush ( databaseName, callback )
  {
    callback = callback || noop;

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.replicatePush( databaseName, (error) =>
      {
        callback( error );
        if(error) reject(error);
        else resolve()
      })
    });
  }

  replicatePull ( databaseName, callback )
  {
    callback = callback || noop;

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.replicatePull( databaseName, (error) =>
      {
        callback( error );
        if(error) reject(error);
        else resolve()
      })
    });
  }

  // For how to create a query: https://github.com/cloudant/CDTDatastore/blob/master/doc/query.md
  // The 'fields' arugment is for projection.  Its an array of fields that you want returned when you do not want the entire doc
  find ( query, fields, databaseName, callback )
  {
    callback = callback || noop;

    if(typeof(fields) === 'function')
    {
      callback = fields;
      fields = null;
    }

    return new Promise( (resolve, reject) =>
    {
      rnsyncModule.find( query, fields, databaseName, ( error, docs ) =>
      {
        if ( !error && Platform.OS === "android" )
        {
          docs = docs.map( doc => JSON.parse( doc ) )
        }

        callback( error, docs );
        if(error) reject(error);
        else resolve(docs)
      } );

    });
  }

  createIndexes(indexes, databaseName, callback) {
    callback = callback || noop;

    return new Promise((resolve, reject) => {
      rnsyncModule.createIndexes(indexes, databaseName, (error, result) => {
        callback( error, result );
        if(error) reject(error);
        else resolve(result)
      })
    });
  }

  deleteDatastoreWithName (databaseName, callback) {
    callback = callback || noop;

    return new Promise((resolve, reject) => {
      rnsyncModule.deleteDatastoreWithName(databaseName, (error) => {
        callback(error);
        if(error) reject(error);
        else resolve();
      });
    });
  }
}

export const rnsyncStorage = new RNSyncStorage();
export default new RNSyncWrapper();

