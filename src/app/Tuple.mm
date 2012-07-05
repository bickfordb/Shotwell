#import "app/Tuple.h"

id First(NSArray *tuple) {
  return [tuple objectAtIndex:0];
}
id Second(NSArray *tuple) {
  return [tuple objectAtIndex:1];
}

NSArray *Tuple0() {
  return [NSArray array];
}

NSArray *Tuple1(id a) {
  if (!a) a = [NSNull null];
  id x[] = {a};
  return [NSArray arrayWithObjects:x count:2];
}

NSArray *Tuple2(id a, id b) {
  if (!a) a = [NSNull null];
  if (!b) b = [NSNull null];
  id x[] = {a, b};
  return [NSArray arrayWithObjects:x count:2];
}

NSArray *Tuple3(id a, id b, id c) {
  if (!a) a = [NSNull null];
  if (!b) b = [NSNull null];
  if (!c) c = [NSNull null];
  id x[] = {a, b, c};
  return [NSArray arrayWithObjects:x count:3];
}

NSArray *Tuple4(id a, id b, id c, id d) {
  if (!a) a = [NSNull null];
  if (!b) b = [NSNull null];
  if (!c) c = [NSNull null];
  if (!d) d = [NSNull null];
  id x[] = {a, b, c, d};
  return [NSArray arrayWithObjects:x count:4];
}


