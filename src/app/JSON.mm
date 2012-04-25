#import "app/JSON.h"
#include <jansson.h>

id FromJSON(json_t *obj) {
  id ret = nil;
  if (!obj) { 
    return nil;
  } else if (json_is_array(obj)) {
    NSMutableArray *a = ret = [NSMutableArray array];
    int n = json_array_size(obj);
    for (int i = 0; i < n; i++)
      [a addObject:FromJSON(json_array_get(obj, i))];
  } else if (json_is_null(obj)) {
    return nil;
  } else if (json_is_integer(obj)) {
    return [NSNumber numberWithLongLong:json_integer_value(obj)];
  } else if (json_is_real(obj)) {
    return [NSNumber numberWithDouble:json_real_value(obj)];
  } else if (json_is_true(obj)) { 
    return [NSNumber numberWithBool:YES];
  } else if (json_is_false(obj)) { 
    return [NSNumber numberWithBool:NO]; 
  } else if (json_is_string(obj)) { 
    ret = [NSString stringWithUTF8String:json_string_value(obj)];
  } else if (json_is_object(obj)) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    ret = d;
    const char *key;
    json_t *val;
    json_object_foreach(obj, key, val) {
     [d setObject:FromJSON(val) forKey:[NSString stringWithUTF8String:key]] ;
    }
  }
  return ret;
}

id FromJSONBytes(const char *s) {
  json_t *o = json_loads(s, JSON_DECODE_ANY, NULL);
  id obj = FromJSON(o);
  json_decref(o);
  return obj;
}

@implementation NSObject (JSON) 
- (NSString *)getJSONEncodedString {
  json_t *o = [self getJSON];
  if (!o)
    return nil;
  char *s = json_dumps(o, JSON_ENCODE_ANY);
  json_decref(o);
  NSString *ret = [NSString stringWithUTF8String:s];
  free(s);
  return ret;
}
- (json_t *)getJSON {
  return NULL;
}
@end

@implementation NSString (JSON) 

- (json_t *)getJSON {
  return json_string(self.UTF8String);
}

- (id)decodeJSON {
  json_t *o = json_loads(self.UTF8String, JSON_DECODE_ANY, NULL);
  id ret = o ? FromJSON(o) : nil;
  if (o)
    json_decref(o);
  return ret;
}
@end

@implementation NSArray (JSON) 
- (json_t *)getJSON {
  json_t *ret = json_array();
  for (NSObject *o in self) {
    json_t *i = [o getJSON];
    if (i) {
      json_array_append(ret, i);
      json_decref(i);
    }
  }
  return ret;
}
@end

@implementation NSNumber (JSON) 
- (json_t *)getJSON { 
  const char *ty = [self objCType];
  json_t *ret = NULL;
  if (strcmp(ty, @encode(BOOL)) == 0)  
    ret = [self boolValue] ? json_true() : json_false();
  else if (strcmp(ty, @encode(char)) == 0) {
    char s[2] = {[self charValue], 0};
    ret = json_string(s);
  } else if (strcmp(ty, @encode(double)) == 0 || strcmp(ty, @encode(float)) == 0 || strcmp(ty, @encode(NSDecimal)) == 0)
    ret = json_real([self doubleValue]);
  else
    ret = json_integer([self longLongValue]);
  return ret;
}
@end

@implementation NSDictionary (JSON) 
- (json_t *)getJSON { 
  json_t *ret = json_object();
  [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    if (![key isKindOfClass:[NSString class]]) {
      return;
    }
    json_t *v = [((NSObject *)obj) getJSON];
    NSString *key0 = (NSString *)key;
    json_object_set(ret, key0.UTF8String, v); 
    if (v) {
      json_decref(v);
    }
  }];
  return ret;
}
@end

@implementation NSData (JSON) 
- (id)decodeJSON {
  json_t *o = json_loadb((const char *)self.bytes, self.length, JSON_DECODE_ANY, NULL);
  id ret = o ? FromJSON(o) : nil;
  if (o)
    json_decref(o);
  return ret;
}
@end

