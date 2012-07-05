#import "app/Level.h"
#import "app/JSON.h"
#import "app/Log.h"
#include <string>

using namespace std;

@implementation Level
@synthesize db = db_;
- (id)initWithPath:(NSString *)path {
  self = [super init];
  if (self) {
    db_ = NULL;
    leveldb::Options opts;
    opts.create_if_missing = true;
    opts.error_if_exists = false;
    leveldb::DB::Open(opts, path.UTF8String, &db_);
  }
  return self;
}

- (void)dealloc {
  delete db_;
  [super dealloc];
}


- (void)setData:(NSData *)data forKey:(NSData *)key {
  leveldb::Slice key0((const char *)key.bytes, key.length);
  leveldb::Slice data0((const char *)data.bytes, data.length);
  db_->Put(leveldb::WriteOptions(), key0, data0);
}

- (NSData *)getDataForKey:(NSData *)key {
  leveldb::Slice key0((const char *)key.bytes, key.length);
  std::string val;
  NSData *ret = nil;
  leveldb::Status st = db_->Get(leveldb::ReadOptions(), key0, &val);
  if (st.ok() && !st.IsNotFound())  {
    ret = [NSData dataWithBytes:val.c_str() length:val.length()];
  }
  return ret;
}
@end

@implementation LevelTable
- (const char *)keyPrefix {
  return "";
}

- (id)initWithLevel:(Level *)level {
  self = [super init];
  if (self) {
    level_ = [level retain];
  }
  return self;
}

- (void)dealloc {
  [level_ release];
  [super dealloc];
}

- (NSData *)encodeKey:(id)key {
  assert(0);
  return [NSData data];
}

- (NSData *)encodeValue:(id)value {
  assert(0);
  return [NSData data];
}

- (id)decodeValue:(NSData *)data {
  assert(0);
  return nil;
}

- (id)decodeKey:(NSData *)bytes  {
  assert(0);
  return nil;
}

- (id)get:(id)key {
  if (!key)
    return nil;
  NSData *keyBytes = [self encodeKey:key];
  string s([self keyPrefix]);
  s.append((const char *)keyBytes.bytes, keyBytes.length);
  std::string val;

  id ret = nil;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), s, &val);
  if (st.ok() && !st.IsNotFound())  {
    NSData *data = [NSData dataWithBytesNoCopy:(void *)val.c_str() length:val.length() freeWhenDone:NO];
    ret = [self decodeValue:data];
  }
  return ret;
}

- (void)put:(id)value forKey:(id)key {
  string key0([self keyPrefix]);
  NSData *keyBytes = [self encodeKey:key];
  key0.append((const char *)keyBytes.bytes, keyBytes.length);
  NSData *valBytes = [self encodeValue:value];
  leveldb::Slice valSlice((const char *)valBytes.bytes, valBytes.length);
  level_.db->Put(leveldb::WriteOptions(), key0, valSlice);
}

- (void)delete:(id)key {
  string key0([self keyPrefix]);
  NSData *keyBytes = [self encodeKey:key];
  key0.append((const char *)keyBytes.bytes, keyBytes.length);
  level_.db->Delete(leveldb::WriteOptions(), key0);
}

- (void)each:(void (^)(id key, id val))block {
  leveldb::Slice prefixSlice([self keyPrefix]);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefixSlice);
  while (i->Valid()) {
    leveldb::Slice keySlice = i->key();
    if (keySlice.starts_with(prefixSlice)) {
      leveldb::Slice valueSlice = i->value();
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      NSData *valueBytes = [NSData dataWithBytesNoCopy:(void *)valueSlice.data() length:valueSlice.size() freeWhenDone:NO];
      keySlice.remove_prefix(prefixSlice.size());
      NSData *keyBytes = [NSData dataWithBytesNoCopy:(void *)keySlice.data() length:keySlice.size() freeWhenDone:NO];
      id key = [self decodeKey:keyBytes];
      id value = [self decodeValue:valueBytes];
      block(key, value);
      [pool release];
    } else {
      break;
    }
    i->Next();
  }
  delete i;
}

- (NSNumber *)nextID {
  std::string key("autoinc:");
  key.append([self keyPrefix]);
  std::string val;
  uint32_t ret = 1;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), key, &val);
  if (st.ok() && !st.IsNotFound()) {
    memcpy(&ret, val.c_str(), MIN(sizeof(ret), val.length()));
    ret++;
  }
  std::string newValue((const char *)&ret, sizeof(ret));
  level_.db->Put(leveldb::WriteOptions(), key, newValue);
  return [NSNumber numberWithUnsignedInt:ret];
}

- (int)count {
  leveldb::Slice prefix([self keyPrefix]);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  int ret = 0;
  while (i->Valid() && i->key().starts_with(prefix)) {
    ret++;
    i->Next();
  }
  delete i;
  return ret;
}

- (void)clear {
  leveldb::Slice prefix([self keyPrefix]);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  while (i->Valid() && i->key().starts_with(prefix)) {
    level_.db->Delete(leveldb::WriteOptions(), i->key());
    i->Next();
  }
  delete i;
}

@end

@interface JSONTable (P)
- (NSData *)encodeJSON:(id)value;
- (id)decodeJSON:(const char *)value length:(size_t)length;
@end

@implementation JSONTable

- (NSData *)encodeValue:(id)value {
  return ToJSONData(value);
}

- (NSData *)encodeKey:(id)value {
  return ToJSONData(value);
}

- (id)decodeValue:(NSData *)data {
  return FromJSONData(data);
}

- (id)decodeKey:(NSData *)data {
  return FromJSONData(data);
}

@end
