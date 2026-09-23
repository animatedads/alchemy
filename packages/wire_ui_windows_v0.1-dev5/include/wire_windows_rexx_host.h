#ifndef WIRE_WINDOWS_REXX_HOST_H
#define WIRE_WINDOWS_REXX_HOST_H
#include <string>
class WireWindowsRexxHost {
public:
  WireWindowsRexxHost();
  ~WireWindowsRexxHost();
  bool start(const std::wstring &applicationDir, std::string &error);
  bool dispatch(const char *source,const char *trigger,const char *detailKey,const char *detailValue,std::string &result,std::string &error);
private:
  struct State; State *state_;
};
#endif
