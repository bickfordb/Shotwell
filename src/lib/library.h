#ifndef _Library_H_
#define _Library_H_

#include <vector>
#include <set>
#include "track.h"
#include <leveldb/db.h>
#include <tr1/memory>

using namespace std;
using namespace std::tr1;

class Library { 
  private:
    leveldb::DB *db_;
  public: 
    Library(); 
    ~Library();
    int Save(const Track &t);
    int Open(const string &path);
    int Close();
    int Get(const string &path, Track *t);
    shared_ptr<vector<shared_ptr<Track> > > GetAll(); 
    int Clear();
    void Scan(vector<string> scan_paths, bool sync);
    int Count();
};

#endif 
