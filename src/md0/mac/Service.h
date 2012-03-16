#ifndef _SERVICE_H_
#define _SERVICE_H_
#include <stdint.h>
#include <string>

using namespace std;

namespace md0 {

struct Service {
  string host_;
  uint16_t port_;
  string name_;
  string mdns_type_;

  bool operator<(Service other) const {
    return  name_ < other.name_
      && host_ < other.host_
      && port_ < other.port_
      && mdns_type_ < other.mdns_type_;
  }
  bool operator==(Service other) const {
    return  name_ == other.name_
      && host_ == other.host_
      && port_ == other.port_
      && mdns_type_ == other.mdns_type_;
  }

  uint16_t port() const { return port_; }
  string host() const { return host_; }
  string mdns_type() const { return mdns_type_; }
  string name() const { return name_; }

  Service(const string &host, 
      uint16_t port,
      const string &name,
      const string &mdns_type) :
        host_(host),
        port_(port),
        name_(name),
        mdns_type_(mdns_type) { }
  ~Service() {} 
};
}
#endif
