#import <Cocoa/Cocoa.h>

enum LogLevel {
  ErrorLogLevel = 0,
  WarnLogLevel,
  InfoLogLevel,
  DebugLogLevel};
#define ERROR(msg, ...) LogMessage(__FILE__, __LINE__, ErrorLogLevel, msg, ##__VA_ARGS__)
#define INFO(msg, ...) LogMessage(__FILE__, __LINE__, InfoLogLevel, msg, ##__VA_ARGS__)
#define DEBUG(msg, ...) LogMessage(__FILE__, __LINE__, DebugLogLevel, msg, ##__VA_ARGS__)
#define WARN(msg, ...) LogMessage(__FILE__, __LINE__, WarnLogLevel, msg, ##__VA_ARGS__)
#define LOG(msg, ...) LogMessage(__FILE__, __LINE__, InfoLogLevel, msg, ##__VA_ARGS__)

void LogMessage(const char *filename, int line, enum LogLevel log_level, NSString *msg, ...);

