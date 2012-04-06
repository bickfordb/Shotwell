#import <Cocoa/Cocoa.h>
#include <leveldb/db.h>
#include <string>

@interface Level : NSObject {
  leveldb::DB *db_;
}

@property (nonatomic) leveldb::DB *db;
- (id)initWithPath:(NSString *)path;

@end


@interface LevelTable : NSObject { 
  Level *level_;
}

- (id)initWithLevel:(Level *)level;
- (id)get:(id)key;
- (void)delete:(id)key;
- (void)put:(id)value forKey:(id)key;
- (void)each:(void (^)(id key, id val))block;
- (char *)encodeKey:(id)key length:(size_t *)length;
- (char *)encodeValue:(id)value length:(size_t *)length;
- (id)decodeValue:(const char *)bytes length:(size_t)length;
- (id)decodeKey:(const char *)bytes length:(size_t)length;
- (void)clear;
- (NSNumber *)nextID;
- (int)count;
@end
