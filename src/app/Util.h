#include <stdint.h>
#include <sys/stat.h>
#include <sys/time.h>
#import <Cocoa/Cocoa.h>
// vim: set filetype=objcpp

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

int64_t TimeSpecToUSec(struct timespec t);
int64_t ModifiedAt(NSString *path);
