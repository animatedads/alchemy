CXX ?= g++
OOREXX_PREFIX ?= /usr/local
CXXFLAGS ?= -O2 -fPIC -std=c++17 -Wall -Wextra
LDFLAGS ?= -shared
all: libnosqlsqlitewriter.so
libnosqlsqlitewriter.so: nosqlsqlitewriter.cpp
	$(CXX) $(CXXFLAGS) -I$(OOREXX_PREFIX)/include $(LDFLAGS) -o $@ $< -lsqlite3
clean:
	rm -f libnosqlsqlitewriter.so
