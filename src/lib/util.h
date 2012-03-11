#ifndef __UTIL_H__
#define __UTIL_H__
#include <string>

using namespace std;

string StringReplace(const string &src, const string &needle, const string &replacement);
string Base64Decode(const string &src); 
string Base64Encode(const string &src); 
string RandBytes(int sz);
void StringAppendFormat(string &s, const string &fmt, ...);
string Format(const string &fmt, ...);

#endif
