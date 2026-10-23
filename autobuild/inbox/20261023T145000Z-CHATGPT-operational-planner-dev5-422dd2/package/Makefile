CXX ?= g++
AR ?= ar
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror -fPIC
CPPFLAGS ?= -Iinclude
all: lib/liboperational_planner.a lib/liboperational_planner.so bin/opctl
lib/liboperational_planner.a: src/operational_planner.cpp include/operational/operational_planner.hpp
	mkdir -p lib build
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c src/operational_planner.cpp -o build/operational_planner.o
	$(AR) rcs $@ build/operational_planner.o
lib/liboperational_planner.so: src/operational_planner.cpp include/operational/operational_planner.hpp
	mkdir -p lib
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -shared src/operational_planner.cpp -o $@
bin/opctl: src/opctl.cpp lib/liboperational_planner.a
	mkdir -p bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) src/opctl.cpp lib/liboperational_planner.a -o $@
test: all
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) tests/test_planner.cpp lib/liboperational_planner.a -o tests/test_planner.bin
	./tests/test_planner.bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) tests/test_capacity.cpp lib/liboperational_planner.a -o tests/test_capacity.bin
	./tests/test_capacity.bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) tests/test_capacity_governor.cpp lib/liboperational_planner.a -o tests/test_capacity_governor.bin
	./tests/test_capacity_governor.bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -pthread tests/test_pressure.cpp lib/liboperational_planner.a -o tests/test_pressure.bin
	./tests/test_pressure.bin
	bash ./tests/test_registry.sh
	bash ./tests/test_capacity_registry.sh
clean:
	rm -rf build lib/*.a lib/*.so bin/opctl tests/test_planner.bin tests/test_pressure.bin tests/test_capacity.bin tests/test_capacity_governor.bin
.PHONY: all test clean
