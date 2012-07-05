#import "app/JSON.h"
#import "app/Log.h"

id FromJSONData(NSData *data) {
   NSError *error = nil;
  id ret = [NSJSONSerialization
    JSONObjectWithData:data
    options:NSJSONReadingAllowFragments | NSJSONReadingMutableLeaves | NSJSONReadingMutableContainers
    error:&error];
  if (error) {
    NSString *s = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    ERROR(@"encountered error decoding: %@, %@, %@", error, data, s);
  }
  return ret;
}

id FromJSONBytes(const char *s) {
  NSData *data = [NSData dataWithBytesNoCopy:(void *)s length:strlen(s) freeWhenDone:NO];
  return FromJSONData(data);
}

NSData *ToJSONData(id obj) {
  NSError *error = nil;
  NSData *ret = obj ? [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error] : nil;
  if (error) {
    ERROR(@"encountered error while writing: %@", error);
  }
  return ret;
}

NSString *ToJSON(id obj) {
  NSData *data = ToJSONData(obj);
  return data ? [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] : nil;
}

@implementation NSObject (JSON)
- (NSString *)getJSONEncodedString {
  return ToJSON(self);
}

@end


