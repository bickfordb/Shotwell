#include "util.h"
#include "base64.h"
#include <openssl/evp.h>
#include <openssl/rand.h>

void StringAppendFormat(
  string &s,
  const string &fmt,
  ...) {
  va_list args; 
  char *fmt_result = NULL;
  va_start(args, fmt);
  int len = vasprintf(&fmt_result, fmt.c_str(), args);  
  if (len >= 0) {
    s.append(fmt_result, len);
    free(fmt_result);
  }
}

string Format(
  const string &fmt, 
  ...) {
  va_list args;
  va_start(args, fmt);
  char *fmt_result = NULL;
  int len = vasprintf(&fmt_result, fmt.c_str(), args);
  if (len >= 0) {
    string s(fmt_result, len);
    free(fmt_result);
    return s;
  }
  string result;
  return result;
}

string RandBytes(int sz) {
  uint8_t buf[sz];
  RAND_bytes(buf, sz);
  string s((const char *)buf, sz);
  return s;
}

string StringReplace(const string &src, const string &needle, const string &replacement) {
  string result(src);
  size_t offset = result.find(needle);
  while (offset != string::npos) {
    result.replace(offset, needle.length(), replacement);
    offset += replacement.length();
    offset = result.find(needle, offset);
  }
  return result;
}

string Base64Encode(const string &src) {
  char *buf = NULL; 
  size_t len = base64_encode(src.c_str(), src.length(), &buf);
  string result;
  if (len > 0) {
    result.append((const char *)buf, len);
    free(buf);
  }
  return result;
}

string Base64Decode(const string &src) { 
  char buf[src.length()];
  size_t len = base64_decode(src.c_str(), buf);
  string result(buf, len);
  return result;
}

