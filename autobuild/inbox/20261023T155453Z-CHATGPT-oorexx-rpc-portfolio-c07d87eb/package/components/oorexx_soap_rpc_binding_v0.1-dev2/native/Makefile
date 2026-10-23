# Build against an explicit ooRexx install/runtime, using libxml2 pkg-config.
CXX ?= c++
OOREXX_INCLUDE ?= /usr/local/include
CXXFLAGS ?= -O2 -g -fPIC -Wall -Wextra -Werror -std=c++17
XML_CFLAGS := $(shell pkg-config --cflags libxml-2.0)
XML_LIBS := $(shell pkg-config --libs libxml-2.0)
all: libsoapxml.so
libsoapxml.so: soapxml.cpp
	$(CXX) $(CXXFLAGS) -I$(OOREXX_INCLUDE) $(XML_CFLAGS) -shared -o $@ $< $(XML_LIBS)
clean:
	rm -f libsoapxml.so
