CXX ?= c++
OOREXX_INCLUDE ?= /usr/local/include
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -Werror -fPIC
LDLIBS ?= -lssl -lcrypto

all: lib/liboorexx_quic_native.so

lib:
	mkdir -p lib

lib/liboorexx_quic_native.so: src/quic_rexx_native.cpp | lib
	$(CXX) -I$(OOREXX_INCLUDE) $(CXXFLAGS) -shared -o $@ $< $(LDLIBS)

clean:
	rm -f lib/liboorexx_quic_native.so
