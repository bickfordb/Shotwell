#import <Cocoa/Cocoa.h>
#include <pthread.h>

typedef void (^ClosedBlock)(void);

pthread_t ForkWith(ClosedBlock block);

// vim: filetype=objcpp
