CXX ?= c++
CC ?= cc
CXXFLAGS ?= -O2 -Wall -Wextra
OOREXX_SRC ?=

.PHONY: test syntax-native syntax-mvs clean

test:
	./tests/run-portable-tests.sh

syntax-native:
	@test -n "$(OOREXX_SRC)" || (echo "Set OOREXX_SRC=/path/to/oorexx-source"; exit 2)
	$(CXX) -std=c++11 -fsyntax-only $(CXXFLAGS) -Iinclude -I$(OOREXX_SRC)/api -I$(OOREXX_SRC)/api/platform/unix src/recordset.cpp platform/portable/RecordSetNativePortable.cpp

syntax-mvs:
	$(CC) -std=c90 -Wall -Wextra -pedantic -fsyntax-only -Iinclude platform/mvs/RecordSetNativeMvs.c

clean:
	rm -f /tmp/oorexx-recordset-native-test
