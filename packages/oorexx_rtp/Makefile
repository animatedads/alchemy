OOREXX_ROOT ?= /usr/local
CXX ?= g++
CXXFLAGS ?= -O2 -fPIC -std=c++17 -Wall -Wextra -Wpedantic
CPPFLAGS += -I$(OOREXX_ROOT)/include
LDFLAGS += -shared
all: build/liboorexx_rtp.so
build/liboorexx_rtp.so: native/oorexx_rtp.cpp
	mkdir -p build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
clean:
	rm -f build/liboorexx_rtp.so
