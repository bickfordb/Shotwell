#import "app/Enum.h"

int IndexOf(id <EnumSeq> seq, id item) {
  __block int i = 0;
  __block int found = -1;
  [seq each:^(id v, bool *stop) {
    if ([item isEqual:v]) {
      found = i;
      *stop = true;
    }
    i++;
  }];
  return found;
}

NSArray *Map(id <EnumSeq> seq, F1 block) {
  NSMutableArray *ret = [NSMutableArray array];
  [seq each:^(id i, bool *stop)  {
    [ret addObject:block(i)];
  }];
  return ret;
}

NSArray *Filter(id <EnumSeq> seq, FilterF1 block) {
  NSMutableArray *ret = [NSMutableArray array];
  [seq each:^(id i, bool *stop)  {
    if (block(i))
      [ret addObject:i];
  }];
  return ret;
}

id Fold(id initial, id <EnumSeq> items, F2 f) {
  __block id ret = initial;
  [items each:^(id i, bool *stop)  {
    ret = f(ret, i);
  }];
  return ret;
}

@implementation NSArray (Enumerated)
- (void)each:(EnumBlock)b {
  bool stop = false;
  for (id i in self) {
    b(i, &stop);
    if (stop)
      break;
  }
}
@end
