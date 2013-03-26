#import "SortedSeq.h"
#import "NSMutableArrayInsert.h"
#import "PThread.h"
#import "Log.h"

@implementation SortedSeq {
  NSPredicate *predicate_;
  NSComparator comparator_;
  NSMutableArray *filteredItems_;
  NSMutableArray *items_;
  NSObject *ilock_;
}

- (NSPredicate *)predicate {
  @synchronized(ilock_) {
    return predicate_;
  }
}

- (NSArray *)getMany:(NSIndexSet *)indices {
  NSMutableArray *ret = [NSMutableArray array];
  if (indices) {
    @synchronized(ilock_) {
      NSUInteger i = indices.firstIndex;
      NSUInteger count = filteredItems_.count;
      while (i != NSNotFound && i < count) {
        id o = filteredItems_[i];
        [ret addObject:o];
        i = [indices indexGreaterThanIndex:i];
      }
    }
  }
  return ret;
}

- (void)each:(EnumBlock)block {
  @synchronized(ilock_) {
    [filteredItems_ each:block];
  }
}

- (void)setPredicate:(NSPredicate *)predicate {
  NSIndexSet *indices;
  @synchronized(ilock_) {
     indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, items_.count)];
  }
  [self willChangeArrangedObjects:indices];
  @synchronized(ilock_) {
    if (predicate != predicate_) {
      NSPredicate *t = predicate_;
      predicate_ = [predicate retain];
      [t release];
      [filteredItems_ removeAllObjects];
      for (id o in items_) {
        if (!predicate_ || [predicate_ evaluateWithObject:o]) {
          [filteredItems_ addObject:o];
        }
      }
    }
  }
  [self didChangeArrangedObjects:indices];
}

- (NSComparator)comparator {
  @synchronized(ilock_) {
    return [comparator_ copy];
  }
}

- (void)setComparator:(NSComparator)comparator {
  NSIndexSet *indices = nil;
  @synchronized(ilock_) {
    [self willChangeValueForKey:@"comparator"];
    indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, items_.count)];
  }
  @synchronized(ilock_) {
    [self willChangeArrangedObjects:indices];
    [comparator_ release];
    comparator_ = [comparator copy];
    if (comparator_) {
      [items_ sortUsingComparator:comparator_];
      [filteredItems_ sortUsingComparator:comparator_];
    }
  }
  [self didChangeValueForKey:@"comparator"];
  [self didChangeArrangedObjects:indices];
}

- (id)init {
  self = [super init];
  if (self) {
    items_ = [[NSMutableArray array] retain];
    filteredItems_ = [[NSMutableArray array] retain];
    ilock_ = [[NSObject alloc] init];
    self.predicate = nil;
    self.comparator = nil;
  }
  return self;
}

- (void)dealloc {
  [filteredItems_ release];
  [items_ release];
  [ilock_ release];
  [predicate_ release];
  [comparator_ release];
  [super dealloc];
}

- (int)count {
  @synchronized(ilock_) {
    return filteredItems_.count;
  }
}

- (id)get:(int)idx {
  @synchronized(ilock_) {
    if (idx >= 0 && idx < filteredItems_.count) {
      return filteredItems_[idx];
    } else {
      return nil;
    }
  }
}

- (NSArray *)array {
  @synchronized(ilock_) {
    return [NSArray arrayWithArray:filteredItems_];
  }
}

- (void)add:(id)something {
  NSIndexSet *indices = nil;
  [self willChangeArrangedObjects:indices];
  @synchronized(ilock_) {
    indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, filteredItems_.count)];
    if (comparator_) {
      [items_ insert:something withComparator:comparator_];
      if (!predicate_ || [predicate_ evaluateWithObject:something]) {
        [filteredItems_ insert:something withComparator:comparator_];
      }
    }
  }
  [self didChangeArrangedObjects:indices];
}

- (void)clear {
  NSIndexSet *indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 0)];
  @synchronized(ilock_) {
    [items_ removeAllObjects];
    [filteredItems_ removeAllObjects];
  }
  [self willChangeArrangedObjects:indices];
  [self didChangeArrangedObjects:indices];
}

- (void)willChangeArrangedObjects:(NSIndexSet *)indices {
  ForkToMainWith(^{
    if (!indices)
      [self willChangeValueForKey:@"arrangedObjects"];
    else
      [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:indices forKey:@"arrangedObjects"];
  });
}

- (void)didChangeArrangedObjects:(NSIndexSet *)indices {
  ForkToMainWith(^{
    if (!indices)
      [self didChangeValueForKey:@"arrangedObjects"];
    else
      [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:indices forKey:@"arrangedObjects"];
  });
}

- (void)remove:(id)something {
  NSIndexSet *indices = nil;
  @synchronized(ilock_) {
    [filteredItems_ removeObject:something];
    [items_ removeObject:something];
    indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, filteredItems_.count)];
  }
  [self willChangeArrangedObjects:indices];
  [self didChangeArrangedObjects:indices];
}

- (NSArray *)all {
  @synchronized(ilock_) {
    return [NSArray arrayWithArray:items_];
  }
}

- (NSUInteger)countOfArrangedObjects {
  return (NSUInteger)[self count];
}

- (id)objectInArrangedObjectsAtIndex:(NSUInteger)index {
  return [self get:(int)index];
}

- (id)arrangedObjectsAtIndexes:(NSIndexSet *)indices {
  return [self getMany:indices];
}

- (void)addObject:(id)something {
  [self add:something];
}

- (void)removeObject:(id)something {
  [self remove:something];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [self count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  id o = [self objectInArrangedObjectsAtIndex:rowIndex];
  NSString *identifier = aTableColumn.identifier;
  if (o && identifier) {
    return [o valueForKey:identifier];
  } else if (o) {
    return o;
  } else {
    return nil;
  }
}


@end
