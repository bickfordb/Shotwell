#include <stdarg.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#import "Log.h"
#import <Cocoa/Cocoa.h>

static bool inited = false;
static NSString *logPath = @"";

void LogInit() {
  if (!inited) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *logsDir = [paths[0] stringByAppendingPathComponent:@"Logs"];
    logPath = [[logsDir stringByAppendingPathComponent:@"Shotwell.log"] retain];
  }
  inited = true;
}

void LogMessage(const char *name, int line, enum LogLevel log_level, NSString *msg, ...) {
  LogInit();
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
  NSString *fmted = [[NSString alloc] initWithFormat:fmt arguments:args];
  if (log_level == WarnLogLevel || log_level == ErrorLogLevel) {
    NSLogv(fmt, args);
  }
  const char *buf = fmted.UTF8String;
  ssize_t n = strlen(buf);
  ssize_t wrote = 0;
  int fd = open(logPath.UTF8String, O_APPEND | O_CREAT | O_WRONLY);
  if (fd > 0) {
    for (ssize_t i = 0; i < n; i += wrote) {
      wrote = write(fd, buf + i, n - i);
      if (wrote < 0) {
        break;
      }
    }
    write(fd, "\n", 1);
  }
  [fmted release];
  close(fd);
}




