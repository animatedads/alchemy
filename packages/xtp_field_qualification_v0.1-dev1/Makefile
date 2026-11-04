# xtp_field_qualification v0.1-dev1: the dev36 field run kit.
# Architecture: Tom Dyer (D-07).  Coding: Claude (Opus 5.5).
#
# bin/xtp-field is one static x86-64 binary built from src/xtp_field.cpp and
# the libxtp sources of XTP_ROOT.  It is committed, with its sha256, so that
# the operator's machine needs no compiler and every field host, whatever its
# distribution, runs the same bytes; run_protected_matrix.sh refuses any
# other binary.  `make` rebuilds it (needs static glibc and libcrypto).
CXX ?= g++
XTP_ROOT ?= ../oorexx_xtp_v0.1-dev36
XTP_SRC = $(addprefix $(XTP_ROOT)/src/,xtp_security.cpp xtp_service.cpp xtp_priority.cpp xtp_wire.cpp xtp_route.cpp xtp_transport.cpp)
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror

all: bin/xtp-field
bin/xtp-field: src/xtp_field.cpp $(XTP_SRC)
	mkdir -p bin
	$(CXX) -I$(XTP_ROOT)/include $(CXXFLAGS) -pthread -static -o $@ src/xtp_field.cpp $(XTP_SRC) -lcrypto -ldl
	strip $@
	cd bin && sha256sum xtp-field > xtp-field.sha256
# Checks the committed binary, then runs the whole controller on this machine
# against a stand-in sshnode.sh (each node a directory here, all on 127.0.0.1).
test: 
	cd bin && sha256sum -c xtp-field.sha256
	bash tests/test_local_matrix.sh
.PHONY: all test
