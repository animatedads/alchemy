OOREXX_ROOT ?= /usr/local
CXX ?= g++
CXXFLAGS ?= -O2 -fPIC -Wall -Wextra -Werror
CPPFLAGS += -I$(OOREXX_ROOT)/include
LDFLAGS ?= -shared
TARGET = librxprocessnative.so
all: $(TARGET)
$(TARGET): rxprocessnative.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
clean:
	rm -f $(TARGET) *.o
