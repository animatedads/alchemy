OOREXX_ROOT ?= /usr/local
CXX ?= g++
CXXFLAGS ?= -O2 -fPIC -std=c++17 -Wall -Wextra -Wpedantic
CPPFLAGS += -I$(OOREXX_ROOT)/include
LDFLAGS += -shared
LDLIBS += -lcrypto -lpthread
all: build/liboorexx_sip.so
build/liboorexx_sip.so: native/oorexx_sip.cpp
	mkdir -p build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)
clean:
	rm -f build/liboorexx_sip.so
