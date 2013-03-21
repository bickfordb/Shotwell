#import <Cocoa/Cocoa.h>
#include <pthread.h>

typedef void (^ClosedBlock)(void);

pthread_t ForkWith(ClosedBlock block);
void ForkToMainWith(ClosedBlock block);

// vim: filetype=objcpp
