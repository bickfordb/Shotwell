#include <stdarg.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>
#import "md0/Log.h"

void LogMessage(const char *name, int line, enum LogLevel log_level, const char *msg, ...) { 
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
  struct timeval  tv;
  struct tm       tm;
  gettimeofday(&tv, NULL);
  localtime_r(&tv.tv_sec, &tm);
  const char *time_fmt = "%Y-%m-%d %T";
  char time_fmted[128];
  strftime(time_fmted, 128, time_fmt, &tm);
  fprintf(stderr, "%s.%d %s:%d:\t%s\t", time_fmted, tv.tv_usec, name, line, level);
  vfprintf(stderr, msg, args);
  fprintf(stderr, "\n");
}
