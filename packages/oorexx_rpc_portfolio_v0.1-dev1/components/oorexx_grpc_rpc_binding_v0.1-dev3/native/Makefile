CXX ?= c++
OOREXX_INCLUDE ?= /usr/local/include
CXXFLAGS ?= -O2 -fPIC -Wall -Wextra -Werror -std=c++17
CURL_CFLAGS := $(shell pkg-config --cflags libcurl)
CURL_LIBS := $(shell pkg-config --libs libcurl)
all: libgrpchttp2.so
libgrpchttp2.so: grpchttp2.cpp
	$(CXX) $(CXXFLAGS) -I$(OOREXX_INCLUDE) $(CURL_CFLAGS) -shared -o $@ $< $(CURL_LIBS)
clean:
	rm -f libgrpchttp2.so

# Streaming engine uses a worker/poll boundary, never a foreign callback into Rexx.
stream: libgrpcstream.so
libgrpcstream.so: grpcstream_core.cpp grpcstream_core.hpp grpcstream_rexx.cpp
	$(CXX) $(CXXFLAGS) -I$(OOREXX_INCLUDE) $(CURL_CFLAGS) -shared -o $@ grpcstream_core.cpp grpcstream_rexx.cpp $(CURL_LIBS) -pthread
stream-fixture: grpcstream_cli
grpcstream_cli: grpcstream_core.cpp grpcstream_core.hpp grpcstream_cli.cpp
	$(CXX) $(CXXFLAGS) $(CURL_CFLAGS) -o $@ grpcstream_core.cpp grpcstream_cli.cpp $(CURL_LIBS) -pthread
