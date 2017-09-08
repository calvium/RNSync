//
//  ReactSync.m
//  reactCloudantSync
//
//  Created by Patrick cremin on 2/17/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "RNSync.h"
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import "ReplicationManager.h"
#import "CloudantSync.h"


@implementation RNSync
{
    NSMutableDictionary *datastores;
    CDTDatastoreManager *manager;
    CDTReplicator *replicator;
    CDTReplicatorFactory *replicatorFactory;
    NSURL *remoteDatabaseURL;
    RCTResponseSenderBlock replicatorDidCompleteCallback;
    RCTResponseSenderBlock replicatorDidErrorCallback;
    ReplicationManager* replicationManager;
}


@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

// TODO make sure this is the best way to create an objc singleton
+ (id)allocWithZone:(NSZone *)zone
{
    static RNSync *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [super allocWithZone:zone]; });
    return sharedInstance;
}

// TODO need to let them name their own datastore! else could conflict with other apps?
RCT_EXPORT_METHOD(init: (NSString *)databaseUrl databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    // Create a CDTDatastoreManager using application internal storage path
    NSError *error = nil;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                               inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"datastores"];
    NSString *path = [storeURL path];
    
    
    if(!manager) {
        manager = [[CDTDatastoreManager alloc] initWithDirectory:path error:&error];
    }
    
    
    if(error)
    {
        callback(@[[NSNumber numberWithLong:error.code]]);
        return;
    }
    if (!datastores) {
        datastores = [NSMutableDictionary new];
    }
    
    // Make name of the datastore the same than the database
    // Store this in a dictionary so we can have more than one?
    datastores[databaseName] = [manager datastoreNamed:databaseName error:&error];
    
    if(error)
    {
        callback(@[[NSNumber numberWithLong:error.code]]);
        return;
    }
    
    replicatorFactory = [[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];
    
    remoteDatabaseURL = [NSURL URLWithString:databaseUrl];
    
    replicationManager = [[ReplicationManager alloc] initWithData:remoteDatabaseURL datastore:datastores[databaseName] replicatorFactory:replicatorFactory];
    
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(replicatePush: (RCTResponseSenderBlock)callback)
{
    [replicationManager push: callback];
}

RCT_EXPORT_METHOD(replicatePull: (RCTResponseSenderBlock)callback)
{
    [replicationManager pull: callback];
}

RCT_EXPORT_METHOD(create: body id:(NSString*)id databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    NSError *error = nil;
    
    CDTDocumentRevision *rev;
    
    // Create a document
    if(id)
    {
        rev = [CDTDocumentRevision revisionWithDocId: id];
    }
    else{
        rev = [CDTDocumentRevision revision];
    }
    
    
    if(!body)
    {
        body = @{};
    }
    
    rev.body = body;
    
    // Save the document to the database
    // revision is nil on failure
    CDTDocumentRevision *revision = [datastores[databaseName] createDocumentFromRevision:rev error:&error];
    if(!revision)
    {
        callback(@[@"document failed to save"]);
    }
    else if(!error)
    {
        NSDictionary *dict = @{ @"id" : revision.docId, @"rev" : revision.revId, @"body" : revision.body };
        
        //NSArray *params = @[dict];
        callback(@[[NSNull null], dict]);
    }
    else{
        callback(@[[NSNumber numberWithLong:error.code]]);
    }
    
}

RCT_EXPORT_METHOD(addAttachment: id name:(NSString*)name path:(NSString*)path type:(NSString*)type databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    NSError *error = nil;
    
    CDTDocumentRevision *revision = [datastores[databaseName] getDocumentWithId:id error:&error];
    
    if(error)
    {
        callback(@[[NSNumber numberWithLong:error.code]]);
        return;
    }
    
    // Add an attachment -- binary data like a JPEG
    CDTUnsavedFileAttachment *att = [[CDTUnsavedFileAttachment alloc]
                                     initWithPath:path   //@"/path/to/image.jpg"
                                     name:name           //@"cute_cat.jpg"
                                     type:type];         //@"image/jpeg"];
    
    revision.attachments[att.name] = att;
    
    CDTDocumentRevision *updated = [datastores[databaseName] updateDocumentFromRevision:revision error:&error];
    
    NSDictionary *dict = @{ @"id" : updated.docId, @"rev" : updated.revId, @"body" : updated.body };
    
    if(!error)
    {
        NSArray *params = @[dict];
        callback(@[[NSNull null], params]);
    }
    else{
        callback(@[[NSNumber numberWithLong:error.code]]);
    }
}

RCT_EXPORT_METHOD(retrieve: (NSString *)id databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    NSError *error = nil;
    
    // Read a document
    CDTDocumentRevision *revision = [datastores[databaseName] getDocumentWithId:id error:&error];
    
    if(!error)
    {
        NSDictionary *dict = @{ @"id" : revision.docId, @"rev" : revision.revId, @"body" : revision.body };
        
        //NSArray *params = @[dict];
        callback(@[[NSNull null], dict]);
    }
    else{
        callback(@[[NSNumber numberWithLong:error.code]]);
    }
}

RCT_EXPORT_METHOD(update: (NSString *)id rev:(NSString *)rev body:(NSDictionary *)body databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    NSError *error = nil;
    
    // Read a document
    CDTDocumentRevision *retrieved = [datastores[databaseName] getDocumentWithId:id rev:rev error:&error];
    
    retrieved.body = (NSMutableDictionary*)body;
    
    CDTDocumentRevision *updated = [datastores[databaseName] updateDocumentFromRevision:retrieved
                                                                                  error:&error];
    
    NSDictionary *dict = @{ @"id" : updated.docId, @"rev" : updated.revId, @"body" : updated.body };
    
    if(!error)
    {
        //NSArray *params = @[dict];
        callback(@[[NSNull null], dict]);
    }
    else{
        callback(@[[NSNumber numberWithLong:error.code]]);
    }
}


RCT_EXPORT_METHOD(delete: (NSString *)id databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    if(!id)
    {
        //NSArray *params = @[[NSNumber numberWithBool:deleted]];
        callback(@[@"called delete without specifying the id"]);
        return;
    }
    
    NSError *error = nil;
    
    CDTDocumentRevision *retrieved = [datastores[databaseName] getDocumentWithId:id error:&error];
    
    [datastores[databaseName] deleteDocumentFromRevision:retrieved
                                                   error:&error];
    if(!error)
    {
        //NSArray *params = @[[NSNumber numberWithBool:deleted]];
        callback(@[[NSNull null]]);
    }
    else{
        callback(@[[NSNumber numberWithLong:error.code]]);
    }
}

RCT_EXPORT_METHOD(deleteDatastoreWithName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    NSError *error = nil;
    
    BOOL deleted = [manager deleteDatastoreNamed:databaseName error: &error];
    
    if(!error)
    {
        //NSArray *params = @[[NSNumber numberWithBool:deleted]];
        callback(@[[NSNull null], [NSNumber numberWithBool:deleted]]);
    }
    else{
        callback(@[[NSNumber numberWithLong:error.code]]);
    }
}


// TODO the results of the query could be huge (run out of memory huge).  Need param for how many items
// to return and paging to get the rest
RCT_EXPORT_METHOD(find: (NSDictionary *)query fields:(NSArray *)fields databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    // TODO waste to new up resultList for every call
    NSMutableArray* resultList = [[NSMutableArray alloc] init];
    
    CDTQResultSet *result = [datastores[databaseName] find:query
                                                      skip:0
                                                     limit:0
                                                    fields:fields
                                                      sort:nil];
    
    [result enumerateObjectsUsingBlock:^(CDTDocumentRevision *rev, NSUInteger idx, BOOL *stop)
     {
         NSDictionary *dict = @{ @"id" : rev.docId, @"rev" : rev.revId, @"body" : rev.body };
         
         [resultList addObject: dict];
     }];
    
    //NSArray *params = @[resultList];
    callback(@[[NSNull null], resultList]);
}


// indexes is a dictionary of dictionaries <String>:<Array<String>>
// indexes has this shape:
// @{
//   @"JSON": @{@"indexName":@[@"property1", @"property2"]},
//   @"TEXT": @{@"indexName":@[@"property1", @"property2"]}
// }

// currently types can be:
// CDTQIndexTypeText = @"TEXT"
// CDTQIndexTypeJSON = @"JSON"


RCT_EXPORT_METHOD(createIndexes:(NSDictionary*)indexes databaseName:(NSString*) databaseName callback:(RCTResponseSenderBlock)callback)
{
    
    
    CDTDatastore* datastore = datastores[databaseName];
    
    
    // TODO: list existing indexes and remove the indexes that need recreation
    // NSLog(@"indexes %@", [datastore listIndexes]);
    // [datastore deleteIndexNamed:@"Some name"];
    
    
    // 1. Iterate through the list of types and separate the indexes by that
    // 2. Take the list of JSON indexes and iterate with something like the thing below
    // 3. Take the list of TEXT indexes if > 0 check that text search is available
    // 4. Then iterate the list of TEXT indexes as below
    // 5. If some index is nil return an error
    // 6. I all indexes exists then return success and update all indexes
    
    NSDictionary* jsonIndexes = indexes[@"JSON"];
    NSDictionary* textIndexes = indexes[@"TEXT"];
    
    __block NSError* error = nil;
    
    if(jsonIndexes.count > 0) {
        
        [jsonIndexes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull jsonKey, id  _Nonnull jsonObject, BOOL * _Nonnull stop) {
            
            NSString* index = [datastore ensureIndexed:jsonObject
                                              withName:jsonKey
                                                ofType:CDTQIndexTypeJSON];
            if (index == nil) {
                error = [[NSError alloc] initWithDomain:@"RNSync" code:-2 userInfo:@{@"message": [NSString stringWithFormat:@"Non valid index build for %@ %@", jsonKey, jsonObject]}];
                *stop = TRUE;
            }
        }];
    }
    
    
    if (textIndexes.count > 0 && !error) {
        if ([datastore isTextSearchEnabled]) {
            // We can just set the tokenizer on settings as of now
            // "porter" is a little bit more fancy than "simple"
            // http://tartarus.org/~martin/PorterStemmer/
            // https://www.sqlite.org/fts3.html#tokenizer  (point 8)
            NSDictionary *settings = @{@"tokenize": @"porter unicode61"};
            
            [textIndexes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull textKey, id  _Nonnull textObject, BOOL * _Nonnull stop) {
                NSString* index = [datastore ensureIndexed:textObject
                                                  withName:textKey
                                                    ofType:CDTQIndexTypeText
                                                  settings:settings];
                if (index == nil) {
                    error = [[NSError alloc] initWithDomain:@"RNSync" code:-2 userInfo:@{@"message": [NSString stringWithFormat:@"Non valid index build for %@ %@", textKey, textObject]}];
                    *stop = TRUE;
                }
            }];
        } else {
            NSLog(@"text search is not enabled");
            error = [[NSError alloc] initWithDomain:@"RNSync" code:-2 userInfo:@{@"message": @"Not possible to create text indexes, review your config"}];
        }
    }
    
    if (!error) {
        [datastore updateAllIndexes]; // optimise times after pull but not necessary
        NSLog(@"indexes %@", [datastore listIndexes]);
        callback(@[[NSNull null], [datastore listIndexes]]);
    } else {
        callback(@[error, [NSNull null]]);
    }
    
}

@end
