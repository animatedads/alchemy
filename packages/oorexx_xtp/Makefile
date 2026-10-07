CXX ?= g++
AR ?= ar
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror -fPIC
CPPFLAGS ?= -Iinclude
LIBOBJ = build/xtp_wire.o build/xtp_route.o build/xtp_transport.o build/xtp_multipath.o build/xtp_socket.o
OOREXX_ROOT ?= $(if $(REXX_BIN),$(abspath $(dir $(REXX_BIN))/..),/usr/local)
OOREXX_INCLUDE ?= $(OOREXX_ROOT)/include
OOREXX_NATIVE_TARGET := $(if $(wildcard $(OOREXX_INCLUDE)/oorexxapi.h),lib/liboorexx_xtp_native.so,)
all: lib/libxtp.a lib/libxtp.so $(OOREXX_NATIVE_TARGET) bin/xtp-admin bin/xtp-connect bin/xtp-listen bin/xtp-multipath bin/xtp-multicast bin/xtp-local
build:
	mkdir -p build
lib bin:
	mkdir -p $@
build/xtp_wire.o: src/xtp_wire.cpp include/xtp/xtp_wire.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_route.o: src/xtp_route.cpp include/xtp/xtp_route.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_socket.o: src/xtp_socket.cpp include/xtp/xtp_socket.hpp include/xtp/xtp_route.hpp include/xtp/xtp_wire.hpp include/xtp/xtp_transport.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_transport.o: src/xtp_transport.cpp include/xtp/xtp_transport.hpp include/xtp/xtp_route.hpp include/xtp/xtp_wire.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_multipath.o: src/xtp_multipath.cpp include/xtp/xtp_multipath.hpp include/xtp/xtp_transport.hpp include/xtp/xtp_route.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
lib/libxtp.a: $(LIBOBJ) | lib
	$(AR) rcs $@ $(LIBOBJ)
lib/libxtp.so: $(LIBOBJ) | lib
	$(CXX) -shared -o $@ $(LIBOBJ)

lib/liboorexx_xtp_native.so: src/xtp_rexx_native.cpp lib/libxtp.a | lib
	$(CXX) $(CPPFLAGS) -I$(OOREXX_INCLUDE) $(CXXFLAGS) -shared -o $@ src/xtp_rexx_native.cpp lib/libxtp.a
bin/xtp-admin: src/xtp_admin.cpp lib/libxtp.a | bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/xtp_admin.cpp lib/libxtp.a
bin/xtp-connect: src/xtp_connect.cpp lib/libxtp.a include/xtp/xtp_socket.hpp include/xtp/xtp_transport.hpp | bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/xtp_connect.cpp lib/libxtp.a
bin/xtp-listen: src/xtp_listen.cpp lib/libxtp.a include/xtp/xtp_socket.hpp include/xtp/xtp_transport.hpp | bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/xtp_listen.cpp lib/libxtp.a
bin/xtp-multipath: src/xtp_multipath_cli.cpp lib/libxtp.a include/xtp/xtp_socket.hpp include/xtp/xtp_multipath.hpp | bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/xtp_multipath_cli.cpp lib/libxtp.a
bin/xtp-multicast: src/xtp_multicast_cli.cpp lib/libxtp.a include/xtp/xtp_socket.hpp include/xtp/xtp_transport.hpp | bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/xtp_multicast_cli.cpp lib/libxtp.a
bin/xtp-local: src/xtp_local.cpp src/xtp_wire.cpp include/xtp/xtp_wire.hpp | bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ src/xtp_local.cpp src/xtp_wire.cpp
clean:
	rm -rf build lib/libxtp.a lib/libxtp.so lib/liboorexx_xtp_native.so bin/xtp-admin bin/xtp-connect bin/xtp-listen bin/xtp-multipath bin/xtp-multicast bin/xtp-local
native:
	@test -f "$(OOREXX_INCLUDE)/oorexxapi.h" || { echo "ooRexx headers not found under $(OOREXX_INCLUDE)" >&2; exit 2; }
	$(MAKE) lib/liboorexx_xtp_native.so
.PHONY: all clean native
