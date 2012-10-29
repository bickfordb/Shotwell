#import "app/Level.h"
#import "app/JSON.h"
#import "app/Log.h"
#include <string>

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

- (void)encodeKey:(id)key to:(std::string *)s{
  assert(0);
}

- (void)encodeValue:(id)value to:(std::string *)s {
  assert(0);
}

- (id)decodeValue:(const leveldb::Slice *)data {
  assert(0);
  return nil;
}

- (id)decodeKey:(const leveldb::Slice *)bytes  {
  assert(0);
  return nil;
}

- (id)get:(id)key {
  if (!key)
    return nil;
  std::string s([self keyPrefix]);
  [self encodeKey:key to:&s];
  std::string val;
  id ret = nil;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), s, &val);
  if (st.ok() && !st.IsNotFound())  {
    leveldb::Slice valSlice(val);
    ret = [self decodeValue:&valSlice];
  }
  return ret;
}

- (void)put:(id)value forKey:(id)key {
  std::string key0([self keyPrefix]);
  [self encodeKey:key to:&key0];
  std::string val;
  [self encodeValue:value to:&val];
  level_.db->Put(leveldb::WriteOptions(), key0, val);
}

- (void)delete:(id)key {
  std::string key0([self keyPrefix]);
  [self encodeKey:key to:&key0];
  level_.db->Delete(leveldb::WriteOptions(), key0);
}

- (void)each:(void (^)(id key, id val))block {
  leveldb::Slice prefixSlice([self keyPrefix]);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefixSlice);
  while (i->Valid()) {
    leveldb::Slice keySlice = i->key();
    if (!keySlice.starts_with(prefixSlice))
      break;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    keySlice.remove_prefix(prefixSlice.size());
    leveldb::Slice valueSlice = i->value();
    id key = [self decodeKey:&keySlice];
    id value = [self decodeValue:&valueSlice];
    block(key, value);
    [pool release];
    i->Next();
  }
  delete i;
}

- (NSNumber *)nextID {
  std::string key("autoinc:");
  key.append([self keyPrefix]);
  std::string val;
  uint64_t ret = 1;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), key, &val);
  if (st.ok() && !st.IsNotFound()) {
    ret = *((uint64_t *)val.c_str());
    //ret = ntohll(ret);
    ret++;
  }
  std::string newValue((const char *)&ret, sizeof(ret));
  level_.db->Put(leveldb::WriteOptions(), key, newValue);
  return [NSNumber numberWithUnsignedLongLong:ret];
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

