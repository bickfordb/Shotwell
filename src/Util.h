#include <stdint.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <string>

#import <Cocoa/Cocoa.h>
// vim: set filetype=objcpp

/* The number of microseconds per second */
extern const uint64_t kUSPerS;

typedef uint64_t usec;

/* Get the Unix epoch time in microseconds */
usec Now();

/* Get a list of subdirectories inside of dirs */
NSArray *GetSubDirectories(NSArray *dirs);
uint64_t TimeSpecToUSec(struct timespec t);
NSDate *ModifiedAt(NSString *path);
NSString *StringToNSString(const std::string *s);
void MakeDirectories(NSString *path);
void RunOnMain(void (^block)(void));
bool Exists(NSString *path);
NSString *AppSupportPath();
