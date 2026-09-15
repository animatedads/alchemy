OOREXX ?= ../oorexx/usr/local
CXX ?= g++
CXXFLAGS ?= -std=c++17 -O0 -fPIC -Wall -Wextra
PYTHON_CONFIG ?= python3-config
PY_CFLAGS := $(shell $(PYTHON_CONFIG) --includes 2>/dev/null)
PY_LDFLAGS := $(shell $(PYTHON_CONFIG) --embed --ldflags 2>/dev/null)

all: build/libforeign_runtime.so examples/libforeign_test.so examples/libtensor_probe.so examples/libforeign_vulkan.so python-provider

build/libforeign_runtime.so: src/foreign_runtime.cpp
	$(CXX) $(CXXFLAGS) -I$(OOREXX)/include -shared -o $@ $< -ldl

build/libforeign_python.so: src/foreign_python.cpp
	$(CXX) $(CXXFLAGS) -I$(OOREXX)/include $(PY_CFLAGS) -shared -o $@ $< $(PY_LDFLAGS)

.PHONY: python-provider
python-provider:
	@if command -v $(PYTHON_CONFIG) >/dev/null 2>&1 && test -n "$(PY_CFLAGS)" && test -n "$(PY_LDFLAGS)"; then \
	  $(MAKE) build/libforeign_python.so OOREXX="$(OOREXX)" CXX="$(CXX)" CXXFLAGS="$(CXXFLAGS)" PYTHON_CONFIG="$(PYTHON_CONFIG)"; \
	else \
	  echo "OPTIONAL Python provider not built: python3-config/embed development support unavailable"; \
	fi

examples/libforeign_test.so: examples/testlib.c
	$(CC) -O2 -fPIC -shared -o $@ $<

examples/libtensor_probe.so: examples/tensor_probe.c
	$(CC) -O2 -fPIC -shared -o $@ $< -ldl

examples/libforeign_vulkan.so: examples/vulkan_provider.cpp
	$(CXX) -std=c++17 -O1 -fPIC -Wall -Wextra -shared -o $@ $< -ldl

clean:
	rm -f build/libforeign_runtime.so build/libforeign_python.so examples/libforeign_test.so examples/libtensor_probe.so examples/libforeign_vulkan.so
