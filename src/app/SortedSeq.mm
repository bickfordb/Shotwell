#import "app/SortedSeq.h"
#import "app/NSMutableArrayInsert.h"

@implementation SortedSeq

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
        id o = [filteredItems_ objectAtIndex:i];
        [ret addObject:o];
        i = [indices indexGreaterThanIndex:i];
      }
    }
  }
  return ret;
}

- (int)index:(id)needle {
  @synchronized (ilock_) {
    NSUInteger i = [filteredItems_ indexOfObject:needle];
    return i == NSNotFound ? -1 : (int)i; 
  }
  return -1;
}
- (void)setPredicate:(NSPredicate *)predicate {
  @synchronized(ilock_) {
    [predicate_ release];
    predicate_ = [predicate retain]; 
    [filteredItems_ removeAllObjects];
    for (id p in items_) {
      if (!predicate || [predicate evaluateWithObject:p]) 
        [filteredItems_ addObject:p];
    }
  }
}

- (NSComparator)comparator {
  @synchronized(ilock_) {
    return [comparator_ copy];
  }
}

- (void)setComparator:(NSComparator)comparator { 
  @synchronized(ilock_) {
    [comparator_ release];
    comparator_ = [comparator copy];
    if (comparator) {
      [items_ sortUsingComparator:comparator];
      [filteredItems_ sortUsingComparator:comparator];
    }
  }
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
      return [filteredItems_ objectAtIndex:idx];
    } else { 
      return nil;
    }
  }
}

- (NSArray *)array { 
  @synchronized(ilock_) {
    return [filteredItems_ copy];
  }
}

- (void)add:(id)something { 
  @synchronized(ilock_) {
    if (comparator_) {
      [items_ insert:something sortedWithComparator:comparator_];  
      if (!predicate_ || [predicate_ evaluateWithObject:something]) 
        [filteredItems_ insert:something sortedWithComparator:comparator_];  
    } else { 
      [items_ addObject:something];
      if (!predicate_ || [predicate_ evaluateWithObject:something]) 
        [filteredItems_ addObject:something];
    }
  }
}

- (void)clear { 
  @synchronized(ilock_) {
    [items_ removeAllObjects];
    [filteredItems_ removeAllObjects];
  }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
  @synchronized(ilock_) {
    return [filteredItems_ countByEnumeratingWithState:state objects:stackbuf count:len];
  }
}

- (void)remove:(id)something { 
  @synchronized(ilock_) {
    [filteredItems_ removeObject:something];
    [items_ removeObject:something];
  }
}

- (NSArray *)all {
  @synchronized(ilock_) {
    return [items_ copy];
  }
}

@end
