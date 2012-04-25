#include <stdint.h>
#import <Cocoa/Cocoa.h>
/* The number of microseconds per second */
extern const int64_t kSPerUS;

/* Get the Unix epoch time in microseconds */
int64_t Now();

/* Get a list of subdirectories inside of dirs */
NSArray *GetSubDirectories(NSArray *dirs);
