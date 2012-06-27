#include <stdint.h>
#import <Cocoa/Cocoa.h>
/* The number of microseconds per second */
extern const int64_t kUSPerS;

typedef int64_t usec;

/* Get the Unix epoch time in microseconds */
usec Now();

/* Get a list of subdirectories inside of dirs */
NSArray *GetSubDirectories(NSArray *dirs);

typedef struct {
  uint32_t sec;
  uint32_t frac;
} NTPTime;

NTPTime NowNTPTime();


