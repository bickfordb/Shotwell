#import "Level.h"

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
  *length = 0;
  return NULL;
}

- (char *)encodeValue:(id)value length:(size_t *)length {
  *length = 0;
  return NULL;
}
- (id)decodeValue:(const char *)bytes length:(size_t)length {
  return nil;
}

- (id)decodeKey:(const char *)bytes length:(size_t)length {
  return nil;
}

- (id)get:(id)key {
  size_t keyLength = 0;
  char *keyBytes = [self encodeKey:key length:&keyLength];
  leveldb::Slice keySlice(keyBytes, keyLength);
  std::string val;

  id ret = nil;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), keySlice, &val);
  if (st.ok() && !st.IsNotFound())  {
    ret = [self decodeValue:val.c_str() length:val.length()];
  }
  free(keyBytes);
  return ret;
}

- (void)put:(id)value forKey:(id)key {
  size_t keyLength = 0;
  char *keyBytes = [self encodeKey:key length:&keyLength];
  size_t valLength = 0;
  char *valBytes = [self encodeValue:value length:&valLength];
  leveldb::Slice keySlice(keyBytes, keyLength);
  leveldb::Slice valSlice(valBytes, valLength);
  level_.db->Put(leveldb::WriteOptions(), keySlice, valSlice);
  free(keyBytes);
  free(valBytes);
}

- (void)delete:(id)key { 
  size_t keyLength = 0;
  char *keyBytes = [self encodeKey:key length:&keyLength];
  leveldb::Slice keySlice(keyBytes, keyLength);
  level_.db->Delete(leveldb::WriteOptions(), keySlice);
  free(keyBytes);
}

- (void)each:(void (^)(id key, id val))block {
  size_t prefixLength = 0;
  char *prefixBytes = [self encodeKey:nil length:&prefixLength];
  leveldb::Slice prefixSlice(prefixBytes, prefixLength);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefixSlice);
  while (i->Valid()) {
    leveldb::Slice keySlice = i->key();
    if (keySlice.starts_with(prefixSlice)) {
      leveldb::Slice valueSlice = i->value();
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      id key = [self decodeKey:keySlice.data() length:keySlice.size()];
      id value = [self decodeValue:valueSlice.data() length:valueSlice.size()];
      block(key, value);
      [pool release];
    } else {
      break;
    }
    i->Next();
  }
  delete i;      
  free(prefixBytes);
}

- (NSNumber *)nextID { 
  std::string key("autoinc:");
  size_t prefixLength = 0;
  char *pfx = [self encodeKey:nil length:&prefixLength];
  key.append(pfx, prefixLength);
  std::string val;
  uint32_t ret = 1;
  leveldb::Status st = level_.db->Get(leveldb::ReadOptions(), key, &val);
  if (st.ok() && !st.IsNotFound()) {
    memcpy(&ret, val.c_str(), MIN(sizeof(ret), val.length()));
    ret++;
  }
  std::string newValue((const char *)&ret, sizeof(ret));
  level_.db->Put(leveldb::WriteOptions(), key, newValue);
  free(pfx);
  return [NSNumber numberWithUnsignedInt:ret];
}

- (int)count { 
  size_t l = 0;
  char *p = [self encodeKey:nil length:&l];
  leveldb::Slice prefix(p, l);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  int ret = 0;
  while (i->Valid() && i->key().starts_with(prefix)) {
    ret++;
    i->Next();
  }
  delete i;
  free(p);
  return ret;   
}

- (void)clear { 
  size_t l = 0;
  char *p = [self encodeKey:nil length:&l];
  leveldb::Slice prefix(p, l);
  leveldb::Iterator *i = level_.db->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  int ret = 0;
  while (i->Valid() && i->key().starts_with(prefix)) {
    level_.db->Delete(leveldb::WriteOptions(), i->key());
    i->Next();
  }
  delete i;
  free(p);
}

@end
