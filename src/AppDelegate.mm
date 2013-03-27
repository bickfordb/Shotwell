#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#import "AppDelegate.h"
#import "Daemon.h"
#import "DaemonBrowser.h"
#import "Library.h"
#import "LocalLibrary.h"
#import "Log.h"
#import "MainWindowController.h"
#import "Util.h"


@implementation AppDelegate

- (void)die:(NSString *)message {
  NSAlert *alert = [NSAlert alertWithMessageText:@"An error occurred" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Need to exit: %@", message];
  [alert runModal];
  [[NSApplication sharedApplication] terminate:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
  __block AppDelegate *weakSelf = self;
  if (![LocalLibrary shared]) {
    [self die:@"Unable to open local library."];
  }
  if (![Daemon shared]) {
    [self die:@"Unable to setup daemon."];
  }
  if (![DaemonBrowser shared]) {
    [self die:@"Unable to setup daemon browser."];
  }
  [[LocalLibrary shared] prune];
  [[MainWindowController shared] setupMenu];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  [[LocalLibrary shared] checkITunesImport];
  [[LocalLibrary shared] checkAutomaticPaths];
}


+ (AppDelegate *)shared {
  return (AppDelegate *)[NSApp delegate];
}
@end
