CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror -pthread
XTP_ROOT = vendor/oorexx_xtp_v0.1-dev24
OPS_ROOT = vendor/oorexx_operational_degradation_planner_v0.1-dev3
XTP_LIB = $(XTP_ROOT)/lib/libxtp.a
OPS_LIB = $(OPS_ROOT)/lib/liboperational_planner.a
CPPFLAGS += -I$(XTP_ROOT)/include -I$(OPS_ROOT)/include
.PHONY: all clean test
all: bin/ssh-xtp
$(OPS_LIB):
	$(MAKE) -C $(OPS_ROOT) lib/liboperational_planner.a
$(XTP_LIB): $(OPS_LIB)
	$(MAKE) -C $(XTP_ROOT) OPERATIONAL_PLANNER_DIR=../oorexx_operational_degradation_planner_v0.1-dev3 lib/libxtp.a
bin/ssh-xtp: src/ssh_xtp.cpp $(XTP_LIB) $(OPS_LIB)
	mkdir -p bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ $< $(XTP_LIB) $(OPS_LIB) -lcrypto
cli-test: $(XTP_ROOT)/src/xtp_connect.cpp $(XTP_LIB) $(OPS_LIB)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ $< $(XTP_LIB) $(OPS_LIB)
test: bin/ssh-xtp cli-test
	bash tests/test_loopback.sh
	python3 tests/test_policy.py
	python3 tests/test_service_admission.py
clean:
	rm -f bin/ssh-xtp cli-test
	$(MAKE) -C $(XTP_ROOT) clean
	$(MAKE) -C $(OPS_ROOT) clean
