
#ifndef _TRACK_H_
#define _TRACK_H_

#include "track.pb.h"
#include <string>
using namespace std;
namespace md0 {
class Track : public ::md0::protobuf::Track { 
 public:
  /* Do global initialization */
  static void Init();
  int ReadTag(const string &url);
};
}
#endif
