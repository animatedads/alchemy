OOREXX_ROOT ?= /usr/local
CXX ?= g++
CXXFLAGS ?= -O2 -fPIC -Wall -Wextra -Werror
CPPFLAGS += -I$(OOREXX_ROOT)/include
LDFLAGS ?= -shared

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  LIBEXT = dylib
else
  LIBEXT = so
endif

TARGET = librxposixgap.$(LIBEXT)

all: $(TARGET)

$(TARGET): rxposixgap.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f librxposixgap.so librxposixgap.dylib *.o
