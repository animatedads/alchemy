CXX ?= g++
AR ?= ar
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror -fPIC
CPPFLAGS ?= -Iinclude
OPERATIONAL_PLANNER_DIR ?= ../oorexx_operational_degradation_planner_v0.1-dev5
OPERATIONAL_CPPFLAGS = -I$(OPERATIONAL_PLANNER_DIR)/include
OPERATIONAL_LIB = $(OPERATIONAL_PLANNER_DIR)/lib/liboperational_planner.a
LIBOBJ = build/xtp_service.o build/xtp_priority.o build/xtp_wire.o build/xtp_route.o build/xtp_transport.o build/xtp_multipath.o build/xtp_socket.o build/xtp_operational.o
OOREXX_ROOT ?= $(if $(REXX_BIN),$(abspath $(dir $(REXX_BIN))/..),/usr/local)
OOREXX_INCLUDE ?= $(OOREXX_ROOT)/include
OOREXX_NATIVE_TARGET := $(if $(wildcard $(OOREXX_INCLUDE)/oorexxapi.h),lib/liboorexx_xtp_native.so,)
all: lib/libxtp.a lib/libxtp.so $(OOREXX_NATIVE_TARGET) bin/xtp-admin bin/xtp-connect bin/xtp-listen bin/xtp-multipath bin/xtp-multicast bin/xtp-local
build:
	mkdir -p build
build/xtp_operational.o: src/xtp_operational.cpp include/xtp/xtp_operational.hpp
	@test -f "$(OPERATIONAL_PLANNER_DIR)/include/operational/operational_planner.hpp" || { echo "Operational planner dependency missing: $(OPERATIONAL_PLANNER_DIR)" >&2; exit 2; }
	$(CXX) $(CPPFLAGS) $(OPERATIONAL_CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_service.o: src/xtp_service.cpp include/xtp/xtp_service.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_priority.o: src/xtp_priority.cpp include/xtp/xtp_priority.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
lib bin:
	mkdir -p $@
build/xtp_wire.o: src/xtp_wire.cpp include/xtp/xtp_wire.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_route.o: src/xtp_route.cpp include/xtp/xtp_route.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_socket.o: src/xtp_socket.cpp include/xtp/xtp_socket.hpp include/xtp/xtp_route.hpp include/xtp/xtp_wire.hpp include/xtp/xtp_transport.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_transport.o: src/xtp_transport.cpp include/xtp/xtp_transport.hpp include/xtp/xtp_route.hpp include/xtp/xtp_wire.hpp include/xtp/xtp_service.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
build/xtp_multipath.o: src/xtp_multipath.cpp include/xtp/xtp_multipath.hpp include/xtp/xtp_transport.hpp include/xtp/xtp_route.hpp | build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<
lib/libxtp.a: $(LIBOBJ) | lib
	$(AR) rcs $@ $(LIBOBJ)
lib/libxtp.so: $(LIBOBJ) | lib
	$(CXX) -shared -o $@ $(LIBOBJ) $(OPERATIONAL_LIB)

lib/liboorexx_xtp_native.so: src/xtp_rexx_native.cpp lib/libxtp.a | lib
	$(CXX) $(CPPFLAGS) -I$(OOREXX_INCLUDE) $(CXXFLAGS) -shared -o $@ src/xtp_rexx_native.cpp lib/libxtp.a $(OPERATIONAL_LIB)
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
test-service: all
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o tests/test_named_service.bin tests/test_named_service.cpp lib/libxtp.a
	./tests/test_named_service.bin
	bash ./tests/test_named_service.sh
	bash ./tests/test_rexx_named_service_binding.sh
test-capacity-rate: all
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -pthread -o tests/test_capacity_rate.bin tests/test_capacity_rate.cpp lib/libxtp.a
	./tests/test_capacity_rate.bin
test-auto-key: all
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -pthread -o tests/test_auto_key.bin tests/test_auto_key.cpp lib/libxtp.a
	./tests/test_auto_key.bin
.PHONY: all clean native test-service test-capacity-rate test-auto-key test-negative test-segmentation test-interop test-sync-diag test-diag-hardening
test-negative: all
	OPERATIONAL_PLANNER_DIR=$(OPERATIONAL_PLANNER_DIR) bash tests/run_negative.sh
test-segmentation: all
	$(CXX) $(CPPFLAGS) $(OPERATIONAL_CPPFLAGS) $(CXXFLAGS) -pthread -DXTP_TRANSPORT_SRC='"$(CURDIR)/src/xtp_transport.cpp"' -o tests/test_segmentation.bin tests/test_segmentation.cpp build/xtp_service.o build/xtp_priority.o build/xtp_wire.o build/xtp_route.o
	./tests/test_segmentation.bin
test-interop: all
	OPERATIONAL_PLANNER_DIR=$(OPERATIONAL_PLANNER_DIR) bash tests/test_interop_selective.sh
test-sync-diag: all
	$(CXX) $(CPPFLAGS) $(OPERATIONAL_CPPFLAGS) $(CXXFLAGS) -pthread -DXTP_DEV29 -DXTP_TRANSPORT_SRC='"$(CURDIR)/src/xtp_transport.cpp"' -o tests/test_sync_diag.bin tests/test_sync_diag.cpp build/xtp_service.o build/xtp_priority.o build/xtp_wire.o build/xtp_route.o
	./tests/test_sync_diag.bin
test-diag-hardening: all
	$(CXX) $(CPPFLAGS) $(OPERATIONAL_CPPFLAGS) $(CXXFLAGS) -pthread -DXTP_TRANSPORT_SRC='"$(CURDIR)/src/xtp_transport.cpp"' -o tests/test_diag_hardening.bin tests/test_diag_hardening.cpp build/xtp_service.o build/xtp_priority.o build/xtp_wire.o build/xtp_route.o
	./tests/test_diag_hardening.bin
