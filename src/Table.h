
#import <Cocoa/Cocoa.h>

typedef void (^Each1)(id key);
typedef void (^Each2)(id key, id value);

@interface Table : NSObject {

}
- (id)initWithPath:(NSString *)path;
- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)value forKeyedSubscript:(id)key;
- (void)eachKey:(Each1)block;
- (void)eachValue:(Each1)block;
- (void)each:(Each2)block;
- (void)clear;
- (int)count;

@end

