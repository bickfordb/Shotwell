#import <Cocoa/Cocoa.h>
#include <leveldb/db.h>
#include <string>

@interface Level : NSObject {
  leveldb::DB *db_;
}

@property (nonatomic) leveldb::DB *db;
- (id)initWithPath:(NSString *)path;
/*
- (void)setData:(NSData *)data forKey:(NSData *)key;
- (NSData *)getDataForKey:(NSData *)key;
*/
@end

@interface LevelTable : NSObject {
  Level *level_;
}

- (id)initWithLevel:(Level *)level;
- (id)get:(id)key;
- (void)delete:(id)key;
- (void)put:(id)value forKey:(id)key;
- (void)each:(void (^)(id key, id val))block;
- (void)encodeKey:(id)key to:(std::string *)out;
- (void)encodeValue:(id)value to:(std::string *)out;
- (id)decodeValue:(const leveldb::Slice *)data;
- (id)decodeKey:(const leveldb::Slice *)data;
- (void)clear;
- (NSNumber *)nextID;
/* Get the number of entries */
- (int)count;
/* Prefix keys with this value.  This allows for multiple indices to exist within one Level database. */
- (const char *)keyPrefix;
@end

