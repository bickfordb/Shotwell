#import <Cocoa/Cocoa.h>
#include <string>
#include <leveldb/db.h>

@interface LevelTable : NSObject {
}

- (id)initWithPath:(NSString *)path;
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
- (void)setObject:(id)newValue forKeyedSubscript:(id)key;
- (id)objectForKeyedSubscript:(id)key;
@end

