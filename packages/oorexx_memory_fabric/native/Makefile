CXX ?= g++
OOREXX_INCLUDE ?= /usr/local/include
CXXFLAGS ?= -O3 -fPIC -std=c++17 -Wall -Wextra
LDFLAGS ?= -shared
TARGET = ../build/libmemory_block_connector.so
SRC = memory_block_connector.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir -p ../build
	$(CXX) $(CXXFLAGS) -I$(OOREXX_INCLUDE) -o $@ $(SRC) $(LDFLAGS)

clean:
	rm -f $(TARGET)
