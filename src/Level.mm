#import "Level.h"
#import "JSON.h"
#import "Log.h"
#import "Util.h"
#include <string>

@implementation LevelTable {
  leveldb::DB *db_;
}

- (id)initWithPath:(NSString *)path {
  self = [super init];
  if (self) {
    db_ = NULL;
    MakeDirectories(path);
    DEBUG(@"%@: opening %@", self, path);
    leveldb::Options opts;
    opts.create_if_missing = true;
    opts.error_if_exists = false;
    leveldb::DB::Open(opts, path.UTF8String, &db_);
    if (!db_) {
      ERROR(@"%@: unable to open: %@", self, path);
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  delete db_;
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
  std::string s;
  [self encodeKey:key to:&s];
  std::string val;
  id ret = nil;
  leveldb::Status st = db_->Get(leveldb::ReadOptions(), s, &val);
  if (st.ok() && !st.IsNotFound())  {
    leveldb::Slice valSlice(val);
    ret = [self decodeValue:&valSlice];
  }
  return ret;
}

- (void)put:(id)value forKey:(id)key {
  std::string key0;
  [self encodeKey:key to:&key0];
  std::string val;
  [self encodeValue:value to:&val];
  db_->Put(leveldb::WriteOptions(), key0, val);
}

- (void)delete:(id)key {
  std::string key0;
  [self encodeKey:key to:&key0];
  db_->Delete(leveldb::WriteOptions(), key0);
}

- (void)each:(void (^)(id key, id val))block {
  leveldb::Slice prefixSlice;
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
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
  std::string key(":_autoinc");
  std::string val;
  uint64_t ret = 1;
  leveldb::Status st = db_->Get(leveldb::ReadOptions(), key, &val);
  if (st.ok() && !st.IsNotFound()) {
    ret = *((uint64_t *)val.c_str());
    //ret = ntohll(ret);
    ret++;
  }
  std::string newValue((const char *)&ret, sizeof(ret));
  db_->Put(leveldb::WriteOptions(), key, newValue);
  return [NSNumber numberWithUnsignedLongLong:ret];
}

- (int)count {
  leveldb::Slice prefix;
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  int ret = 0;
  while (i->Valid()) {
    ret++;
    i->Next();
  }
  delete i;
  return ret;
}

- (void)clear {
  leveldb::Slice prefix("");
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  while (i->Valid()) {
    db_->Delete(leveldb::WriteOptions(), i->key());
    i->Next();
  }
  delete i;
}

- (void)setObject:(id)newValue forKeyedSubscript:(id)key {
  [self put:newValue forKey:key];
}

- (id)objectForKeyedSubscript:(id)key {
  return [self get:key];
}
@end

