#import "md0/Level.h"
#import "md0/JSON.h"
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

- (char *)encodeKey:(id)key length:(size_t *)length {
  assert(0);
  *length = 0;
  return NULL;
}

- (char *)encodeValue:(id)value length:(size_t *)length {
  assert(0);
  *length = 0;
  return NULL;
}
- (id)decodeValue:(const char *)bytes length:(size_t)length {
  assert(0);
  return nil;
}

- (id)decodeKey:(const char *)bytes length:(size_t)length {
  assert(0);
  return nil;
}

- (id)get:(id)key {
  size_t keyLength = 0;
  char *keyBytes = [self encodeKey:key length:&keyLength];
  string s([self keyPrefix]);
  s.append(keyBytes, keyLength);
  free(keyBytes);
  std::string val;

  id ret = nil;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), s, &val);
  if (st.ok() && !st.IsNotFound())  {
    ret = [self decodeValue:val.c_str() length:val.length()];
  }
  return ret;
}

- (void)put:(id)value forKey:(id)key {
  string key0([self keyPrefix]);
  size_t keyLength = 0;
  char *keyBytes = [self encodeKey:key length:&keyLength];
  key0.append(keyBytes, keyLength);
  free(keyBytes);
  size_t valLength = 0;
  char *valBytes = [self encodeValue:value length:&valLength];
  leveldb::Slice valSlice(valBytes, valLength);
  level_.db->Put(leveldb::WriteOptions(), key0, valSlice);
  free(valBytes);
}

- (void)delete:(id)key { 
  string key0([self keyPrefix]);
  size_t keyLength = 0;
  char *keyBytes = [self encodeKey:key length:&keyLength];
  key0.append(keyBytes, keyLength);
  free(keyBytes);
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
      id key = [self 
        decodeKey:prefixSlice.size() + keySlice.data() 
        length:keySlice.size() - prefixSlice.size()];
      id value = [self
        decodeValue:valueSlice.data()
        length:valueSlice.size()];
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
  int ret = 0;
  while (i->Valid() && i->key().starts_with(prefix)) {
    level_.db->Delete(leveldb::WriteOptions(), i->key());
    i->Next();
  }
  delete i;
}

@end

@interface JSONTable (P)
- (char *)encodeJSON:(id)value length:(size_t *)length;
- (id)decodeJSON:(const char *)value length:(size_t)length;
@end

@implementation JSONTable
- (char *)encodeJSON:(id)value length:(size_t *)length {
  json_t *js = [((NSObject *)value) getJSON];
  char *ret = js ? json_dumps(js, JSON_ENCODE_ANY) : NULL;
  *length = (js && ret) ? strlen(ret) + 1 : 0;      
  if (js) 
    json_decref(js); 
  return ret; 
}

- (id)decodeJSON:(const char *)bytes length:(size_t)length {
  return length > 0 ? FromJSONBytes(bytes) : nil;
}

- (char *)encodeValue:(id)value length:(size_t *)length {
  return [self encodeJSON:value length:length];
}

- (char *)encodeKey:(id)value length:(size_t *)length {
  return [self encodeJSON:value length:length];
}

- (id)decodeValue:(const char *)bytes length:(size_t)length { 
  return [self decodeJSON:bytes length:length];
}

- (id)decodeKey:(const char *)bytes length:(size_t)length { 
  return [self decodeJSON:bytes length:length];
}

@end
