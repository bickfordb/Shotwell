#import "Dict.h"

@implementation Dict

- (id)init {
  self = [super init];
  if (self) {
    dictionary_ = [[NSMutableDictionary dictionary] retain];
  }
  return self;
}

- (void)dealloc {
  [dictionary_ release];
  [super dealloc];
}

+ (id)dict {
  return [[[Dict alloc] init] autorelease];
}

- (void)set:(id)key value:(id)value {
  @synchronized(dictionary_) {
    [dictionary_ setObject:value forKey:key];
  }
}

- (id)get:(id)key {
  @synchronized(dictionary_) {
    return [dictionary_ objectForKey:key];
  }
}

- (void)clear {
  @synchronized(dictionary_) {
    [dictionary_ removeAllObjects];
  }
}

- (NSArray *)keys {
  NSArray *ks = nil;
  @synchronized(dictionary_) {
    ks = [dictionary_ allKeys];
  }
  return ks;
}

- (NSArray *)values {
  NSArray *vs = nil;
  @synchronized(dictionary_) {
    vs = [dictionary_ allValues];
  }
  return vs;
}

- (NSArray *)items {
  NSMutableArray *is = [NSMutableArray array];
  @synchronized(dictionary_) {
    [dictionary_ enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      id objs[2];
      objs[0] = key;
      objs[1] = obj;
      NSMutableArray *vs = [NSMutableArray arrayWithObjects:objs count:2];
      [is addObject:vs];
    }];
  }
  return is;
}

- (id)pop:(id)key {
  @synchronized(dictionary_) {
    id item = [dictionary_ objectForKey:key];
    [dictionary_ removeObjectForKey:key];
    return item;
  }
}
@end
