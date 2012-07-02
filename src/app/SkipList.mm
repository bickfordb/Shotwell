#import "app/SkipList.h"
#import "app/Log.h"

#ifndef DEBUGSKIPLIST
#define DEBUGSKIPLIST 0
#endif

static const long kMaxLevel = 12;

static NSComparator DefaultComparator = ^(id left, id right) {
  NSObject *l = left;
  NSObject *r = right;
  NSComparisonResult ret = NSOrderedSame;
  if (l == r) {
    return ret;
  }
  NSUInteger hl = [l hash];
  NSUInteger hr =  [r hash];
  if (hl < hr) {
    ret = NSOrderedAscending;
  } else if (hl > hr) {
    ret = NSOrderedDescending;
  } else {
    if ([l isEqual:r]) {
      ret = NSOrderedSame;
    } else {
      // settle ties by identity
      if (l < r) {
        ret = NSOrderedAscending;
        // we checked for same address so the address must be descending
      } else {
        ret = NSOrderedDescending;
      }
    }
  }
  return ret;
};

typedef struct SkipListNode {
  id key;
  id value;
  #if DEBUGSKIPLIST
  int level;
  #endif
  int *length;
  struct SkipListNode **forward;
} Node;

static Node *node_new(id key, id value, int level) {
  Node *node = (Node *)calloc(1, sizeof(Node));
  node->key = [key retain];
  node->value = [value retain];
  #if DEBUGSKIPLIST
  node->level = level;
  #endif
  node->forward = (Node **)calloc(level, sizeof(Node *));
  node->length = (int *)calloc(level, sizeof(int));
  for (int i = 0; i < level; i++) {
    node->length[i] = 1;
  }
  return node;
}

static void node_free(Node *node) {
  [node->key release];
  [node->value release];
  free(node->forward);
  free(node->length);
  free(node);
}

@interface SkipList (Private)
- (int)randomLevel;
- (Node *)findNodePreviousToKey:(id)key previousNodes:(Node **)prev;
- (void)reindex;
@end

@implementation SkipList
+ (void)initialize {
  int fd = open("/dev/urandom", O_RDONLY);
  unsigned seed = 0;
  if (fd >= 0) {
    size_t ret = read(fd, &seed, sizeof(seed));
    (void)ret;
    close(fd);
    srandom(seed);
  }
}

- (NSComparator)comparator {
  return [comparator_ copy];
}

- (void)setComparator:(NSComparator)comparator {
  if (comparator_ == comparator)
    return;
  if (!comparator)
    comparator = DefaultComparator;
  [self willChangeValueForKey:@"comparator"];
  NSComparator t = comparator_;
  comparator_ = [[comparator copy] retain];
  [t release];
  [self reindex];
  [self didChangeValueForKey:@"comparator"];
}

- (void)reindex {
  count_ = 1;
  Node *oldHead = head_;
  head_ = node_new(nil, nil, kMaxLevel);
  level_ = 1;
  count_ = 0;
  Node *i = oldHead->forward[0];
  while (i) {
    [self set:i->key to:i->value];
    Node *t = i;
    i = t->forward[0];
    node_free(t);
  }
  node_free(oldHead);
}

- (void)eachItem:(MapEnumBlock)block {
  bool keepGoing = true;
  for (Node *i = head_->forward[0]; i && keepGoing; i = i->forward[0]) {
    block(i->key, i->value, &keepGoing);
  }
}

- (void)each:(EnumBlock)block {
  bool keepGoing = true;
  for (Node *i = head_->forward[0]; i && keepGoing; i = i->forward[0]) {
    block(i->key, &keepGoing);
  }
}

- (id)at:(long)index {
  if (index < 0 || index >= count_)
    return nil;
  index++;
  long pos = 0;
  Node *node = head_;
  for (int level = level_ - 1; level >= 0; level--) {
    while (node->forward[level] // doesn't point to nil
        && ((pos + node->length[level]) <= index)) {
      pos = pos + node->length[level];
      node = node->forward[level];
    }
  }
  return node->key;
}

- (NSString *)description {
  NSString *ret = @"";
  for (Node *node = head_;
      node;
      node = node->forward[0]) {
    NSString *nodeRepr = @"\n{";
    nodeRepr = [nodeRepr stringByAppendingFormat:@"0x%08X\nkey: %@\nedges: ", node, node->key];
    #if DEBUGSKIPLIST
    for (int i = node->level - 1; i >= 0; i--) {
      nodeRepr = [nodeRepr stringByAppendingFormat:@" 0x%08X,%d", node->forward[i], node->length[i]];
    }
    #endif
    nodeRepr = [nodeRepr stringByAppendingString:@"}\n"];
    ret = [ret stringByAppendingString:nodeRepr];
  }
  return ret;
}

- (void)clear {
  Node *node = head_->forward[0];
  while (node) {
    Node *next = node->forward[0];
    node_free(node);
    node = next;
  }
  for (int i = 0; i < kMaxLevel; i++) {
    head_->forward[i] = NULL;
  }
  level_ = 1;
  count_ = 0;
}

- (id)initWithComparator:(NSComparator)comparator {
  self = [super init];
  if (self) {
    if (!comparator)
      comparator = DefaultComparator;
    head_ = node_new(nil, nil, kMaxLevel);
    count_ = 0;
    level_ = 1;
    comparator_ = [[comparator copy] retain];
  }
  return self;
}

- (int)randomLevel {
  int kBranching = 4;
  int level = 1;
  while (level < kMaxLevel && ((lrand48() % kBranching) == 0)) {
    level++;
  }
  assert(level > 0);
  assert(level <= kMaxLevel);
  return level;
}

- (Node *)findNodePreviousToKey:(id)key previousNodes:(Node **)prev {
  if (prev)
    memset(prev, 0, sizeof(prev));
  Node *x = head_;
  for (int level = level_ - 1; level >= 0; level--) {
    while (x->forward[level] && comparator_(x->forward[level]->key, key) < 0) {
      x = x->forward[level];
    }
    if (prev)
      prev[level] = x;
  }
  return x;
}

- (void)delete:(id)key {
  Node *update[kMaxLevel];
  Node *x = [self findNodePreviousToKey:key previousNodes:update];
  if (!x) {
    return;
  }
  x = x->forward[0];
  if (comparator_(x->key, key) != 0) {
    return;
  }
  for (int level = 0; level < level_; level++) {
    if (update[level]->forward[level] == x) {
      update[level]->length[level] += x->length[level] - 1;
      update[level]->forward[level] = x->forward[level];
    } else {
      update[level]->length[level] -= 1;
    }
  }
  node_free(x);
  for (int i = level_ - 1; i > 0; i--) {
    if (head_->forward[i] == NULL) {
       level_--;
    }
  }
  count_--;
}

- (void)dealloc {
  [comparator_ release];
  Node *node = head_;
  while (node) {
    Node *next = node->forward[0];
    node_free(node);
    node = next;
  }
  [super dealloc];
}

- (id)get:(id)key {
  Node *prev = [self findNodePreviousToKey:key previousNodes:NULL];
  if (prev && prev->forward[0] && comparator_(key, prev->forward[0]->key) == 0) {
    return prev->forward[0]->value;
  } else {
    return nil;
  }
}

- (NSArray *)keys {
  NSMutableArray *keys = [NSMutableArray array];
  for (Node *i = head_->forward[0]; i; i = i->forward[0]) {
    [keys addObject:i->key];
  }
  return keys;
}

- (NSArray *)values {
  NSMutableArray *values = [NSMutableArray array];
  for (Node *i = head_->forward[0]; i; i = i->forward[0]) {
    [values addObject:i->value];
  }
  return values;
}

- (NSArray *)items {
  NSMutableArray *items = [NSMutableArray array];
  for (Node *i = head_->forward[0]; i; i = i->forward[0]) {
    id xs[2];
    xs[0] = i->key;
    xs[1] = i->value;
    [items addObject:[NSArray arrayWithObjects:xs count:2]];
  }
  return items;
}

- (void)set:(id)key to:(id)object {
  Node *update[kMaxLevel];
  int updatePos[kMaxLevel];
  int pos = 0;
  Node *x = head_;
  for (int i = kMaxLevel - 1; i >= 0; i--) {
    update[i] = head_;
    updatePos[i] = 0;
  }
  // memo-ize the last comparison to reduce the number of comparisons.
  id lastCmpKey = nil;
  int lastCmpVal = -1;
  for (int level = level_ - 1; level >= 0; level--) {
    while (true) {
      if (!x) break;
      if (!x->forward[level]) break;
      if (lastCmpKey != x->forward[level]->key) {
        lastCmpVal = comparator_(x->forward[level]->key, key);
        lastCmpKey = x->forward[level]->key;
      }
      if (lastCmpVal >= 0) break;
      x = x->forward[level];
      updatePos[level] += x->length[level];
      pos += x->length[level];
    }
    update[level] = x;
  }
  if (x) {
    x = x->forward[0];
    pos++;
    if (x) {
      if (lastCmpKey != x->key) {
        lastCmpKey = x->key;
        lastCmpVal = comparator_(x->key, key);
      }
      if (lastCmpVal == 0) {
        [x->key release];
        [x->value release];
        x->key = [key retain];
        x->value = [object retain];
        return;
      }
    }
  }
  int newLevel = [self randomLevel];
  if (newLevel > level_) {
    for (int i = level_; i < newLevel; i++) {
      update[i] = head_;
    }
    level_ = newLevel;
  }

  Node *node = node_new(key, object, newLevel);
  int steps = 0;
  for (int i = 0; i < newLevel; i++) {
    node->forward[i] = update[i] ? update[i]->forward[i] : NULL;
    update[i]->forward[i] = node;
    node->length[i] = update[i]->length[i] - steps;
    update[i]->length[i] = steps + 1;
    steps += updatePos[i];
  }
  for (int i = newLevel; i < kMaxLevel; i++) {
    update[i]->length[i] += 1;
  }
  count_++;
}

- (bool)contains:(id)key {
  Node * x = [self findNodePreviousToKey:key previousNodes:NULL];
  x = x->forward[0];
  if (x && comparator_(x->key, key) == 0) {
    return true;
  } else {
    return false;
  }
}

- (long)count {
  return count_;
}

@end


@implementation ConcurrentSkipList
- (id)initWithComparator:(NSComparator)comparator {
  self = [super init];
  if (self) {
    skipList_ = [[SkipList alloc] initWithComparator:comparator];
  }
  return self;
}

- (void)dealloc {
  [skipList_ release];
  [super dealloc];
}

- (void)set:(id)key to:(id)object {
  @synchronized (skipList_) {
    [skipList_ set:key to:object];
  }
}
- (bool)contains:(id)object {
  @synchronized (skipList_) {
    return [skipList_ contains:object];
  }
}

- (NSString *)description {
  @synchronized (skipList_) {
    return [skipList_ description];
  }
}
- (void)delete:(id)object {
  @synchronized (skipList_) {
    [skipList_ delete:object];
  }
}
- (long)count {
  @synchronized (skipList_) {
    return [skipList_ count];
  }
}

- (void)clear {
  @synchronized (skipList_) {
    return [skipList_ clear];
  }
}

- (id)at:(long)index {
  @synchronized (skipList_) {
    return [skipList_ at:index];
  }
}

- (NSArray *)items {
  @synchronized (skipList_) {
   return [skipList_ items];
  }
}

- (NSArray *)keys {
  @synchronized (skipList_) {
   return [skipList_ keys];
  }
}

- (NSArray *)values {
  @synchronized (skipList_) {
   return [skipList_ values];
  }
}

- (id)get:(id)key {
  @synchronized(skipList_) {
    return [skipList_ get:key];
  }
}

- (void)setComparator:(NSComparator)c {
  @synchronized(skipList_) {
    [self willChangeValueForKey:@"comparator"];
    [skipList_ setComparator:c];
    [self didChangeValueForKey:@"comparator"];
  }
}

- (NSComparator)comparator {
  @synchronized(skipList_) {
    return [skipList_ comparator];
  }
}

- (void)each:(EnumBlock)block {
  @synchronized(skipList_) {
    [skipList_ each:block];
  }
}
- (void)eachItem:(MapEnumBlock)block {
  @synchronized(skipList_) {
    [skipList_ eachItem:block];
  }
}
@end
