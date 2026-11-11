# Media Object Access native H.264 codec-only provider.
# ooRexx owns media/container/PTS/seeking; native provider owns decode+RGB24.
# Requires ooRexx 5.x native headers and shared rexxapi, C++17.
# Runtime expects installed libavcodec.so.61, libavutil.so.59, libswscale.so.8.
# Build explicitly for the matching 64-bit host; no codec library is bundled.
OOREXX_ROOT ?= /usr/local
CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -fPIC -Wall -Wextra
CPPFLAGS += -I$(OOREXX_ROOT)/include
LDFLAGS += -L$(OOREXX_ROOT)/lib -Wl,--no-as-needed -lrexxapi -Wl,--as-needed -ldl
all: libmoa_h264.so
libmoa_h264.so: moa_h264_codec.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -shared -o $@ $< $(LDFLAGS)
clean:
	rm -f libmoa_h264.so
.PHONY: all clean