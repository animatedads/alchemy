CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror -fPIC
OOREXX_ROOT ?= /usr/local
OOREXX_INCLUDE ?= $(OOREXX_ROOT)/include
NORM_ROOT ?= /usr/local
NORM_INCLUDE ?= $(NORM_ROOT)/include
NORM_LIBDIR ?= $(NORM_ROOT)/lib
LDFLAGS ?=
LDLIBS ?= -lnorm -lpthread
all: lib/liboorexx_norm_native.so
lib:
	mkdir -p lib
lib/liboorexx_norm_native.so: native/norm_rexx_native.cpp | lib
	$(CXX) $(CXXFLAGS) -I$(OOREXX_INCLUDE) -I$(NORM_INCLUDE) -shared -o $@ $< -L$(NORM_LIBDIR) $(LDFLAGS) $(LDLIBS)
clean:
	rm -rf lib
.PHONY: all clean
