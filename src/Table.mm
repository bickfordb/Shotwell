#import "Table.h"
#import "Log.h"
#import "Util.h"

#include <string>
#include <leveldb/db.h>

static NSData *Encode(id object) {
  NSError *error = nil;
  return [NSPropertyListSerialization
    dataWithPropertyList:object format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListMutableContainersAndLeaves error:&error];
}

static id Decode(const std::string *s) {
  NSError *error = nil;
  NSData *data = [[[NSData alloc] initWithBytesNoCopy:(void *)s->c_str() length:s->length() freeWhenDone:NO] autorelease];
  id result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:NULL error:&error];
  return result;
}

static id DecodeSlice(const leveldb::Slice *s) {
  NSError *error = nil;
  NSData *data = [[[NSData alloc] initWithBytesNoCopy:(void *)s->data() length:s->size() freeWhenDone:NO] autorelease];
  id result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:NULL error:&error];
  return result;
}

@implementation Table {
  leveldb::DB *db_;
}

- (id)initWithPath:(NSString *)path {
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

- (id)objectForKeyedSubscript:(id)key {
  if (!key) { return nil; }
  NSData *keyData = Encode(key);
  leveldb::Slice keyS((const char *)keyData.bytes, keyData.length);
  std::string val;
  leveldb::Status st = db_->Get(leveldb::ReadOptions(), keyS, &val);
  id item = nil;
  if (st.ok() && !st.IsNotFound()) {
    item = Decode(&val);
  }
  return item;
}

- (void)setObject:(id)value forKeyedSubscript:(id)key {
  if (!key) return;
  NSData *keyData = Encode(key);
  leveldb::Slice keyS((const char *)keyData.bytes, keyData.length);
  if (value != nil) {
    NSData *valueData = Encode(value);
    leveldb::Slice valueS((const char*)valueData.bytes, valueData.length);
    db_->Put(leveldb::WriteOptions(), keyS, valueS);
  } else {
    db_->Delete(leveldb::WriteOptions(), keyS);
  }
}

- (void)eachKey:(Each1)block {
  leveldb::Slice prefix("");
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  while (i->Valid()) {
    leveldb::Slice key = i->key();
    block(DecodeSlice(&key));
    i->Next();
  }
  delete i;
}

- (void)eachValue:(Each1)block {
  leveldb::Slice prefix("");
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  while (i->Valid()) {
    leveldb::Slice val = i->value();
    block(DecodeSlice(&val));
    i->Next();
  }
  delete i;
}

- (void)each:(Each2)block {
  leveldb::Slice prefix("");
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  while (i->Valid()) {
    leveldb::Slice key = i->key();
    leveldb::Slice val = i->value();
    block(DecodeSlice(&key), DecodeSlice(&val));
    i->Next();
  }
  delete i;
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

- (int)count {
  int ret = 0;
  leveldb::Slice prefix("");
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->Seek(prefix);
  while (i->Valid()) {
    ret++;
  }

  delete i;
  return ret;
}

@end

