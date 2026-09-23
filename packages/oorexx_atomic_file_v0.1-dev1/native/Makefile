OOREXX_ROOT ?= /usr/local
CXX ?= g++
CXXFLAGS ?= -O2 -fPIC -Wall -Wextra -Werror
CPPFLAGS += -I$(OOREXX_ROOT)/include
LDFLAGS ?= -shared
TARGET = librxatomicnative.so
all: $(TARGET)
$(TARGET): rxatomicnative.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
clean:
	rm -f $(TARGET) *.o
