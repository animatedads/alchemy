CC ?= cc
CFLAGS ?= -std=c11 -O2 -fPIC -Wall -Wextra -Werror -pthread
LDFLAGS ?= -shared -pthread -ldl
all: libservice_playout.so
libservice_playout.so: service_playout.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
clean:
	rm -f libservice_playout.so
