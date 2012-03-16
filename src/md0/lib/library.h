#ifndef _TRACK_COLLECTION_H_
#define _TRACK_COLLECTION_H_
#include <vector>
#include "md0/lib/track.h"

namespace md0 { 

class Library {
 public:
  virtual ~Library() {};
  virtual void GetAll(vector<Track> *to_tracks) = 0;
  virtual int Count() = 0;  
  virtual long double last_update() { 
    return 0; 
  };
};
}

#endif
