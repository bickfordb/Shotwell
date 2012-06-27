#include <stdarg.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#import "app/Log.h"
#import <Cocoa/Cocoa.h>

void LogMessage(const char *name, int line, enum LogLevel log_level, NSString *msg, ...) {
  va_list args;
  va_start(args, msg);
  const char *level = "";
  switch (log_level) {
    case InfoLogLevel:
      level = "INFO";
      break;
    case WarnLogLevel:
      level = "WARN";
      break;
    case ErrorLogLevel:
      level = "ERROR";
      break;
    case DebugLogLevel:
      level = "DEBUG";
  }
  NSString *fmt = [NSString stringWithFormat:@"%s:%d:\t%s\t%@", name, line, level, msg, nil];
  NSLogv(fmt, args);
}
