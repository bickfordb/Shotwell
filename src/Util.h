#import <Cocoa/Cocoa.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <string>
#include <dispatch/dispatch.h>

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
NSString *LocalLibraryPath();

#include <pthread.h>

typedef void (^ClosedBlock)(void);

pthread_t ForkWith(ClosedBlock block);
void ForkToMainWith(ClosedBlock block);
void IgnoreSigPIPE();
typedef void (^On0)(void);
typedef void (^On1)(id a);
typedef void (^On2)(id a, id b);
typedef void (^On3)(id a, id b, id c);
typedef void (^On4)(id a, id b, id c, id d);
typedef void (^On5)(id a, id b, id c, id d, id e);

void Notify(NSString *name, id sender, NSDictionary *info);
dispatch_source_t CreateDispatchTimer(double seconds, dispatch_queue_t queue, dispatch_block_t block);
NSError *CheckError(NSError **error, NSString *domain, int code);
NSError *MkError(NSString *domain, int code);

// vim: filetype=objcpp
