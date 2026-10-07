#ifndef OOREXX_CLI_UI_H
#define OOREXX_CLI_UI_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define OOREXX_CLI_UI_ABI 2u

typedef uint64_t CliUiHandle;
typedef enum { CLIUI_OK=0, CLIUI_EINVAL=1, CLIUI_ENOTSUP=2, CLIUI_ESTATE=3, CLIUI_EIO=4 } CliUiResult;
typedef enum { CLIUI_BACKEND_ANSI=1, CLIUI_BACKEND_CURSES=2 } CliUiBackend;
typedef enum { CLIUI_KEY_TEXT=1, CLIUI_KEY_UP, CLIUI_KEY_DOWN, CLIUI_KEY_LEFT, CLIUI_KEY_RIGHT, CLIUI_KEY_HOME, CLIUI_KEY_END, CLIUI_KEY_PAGE_UP, CLIUI_KEY_PAGE_DOWN, CLIUI_KEY_ENTER, CLIUI_KEY_ESCAPE, CLIUI_KEY_TAB, CLIUI_KEY_BACKTAB, CLIUI_KEY_BACKSPACE, CLIUI_KEY_DELETE, CLIUI_KEY_FUNCTION } CliUiKeyKind;
typedef enum { CLIUI_MOD_SHIFT=1u, CLIUI_MOD_ALT=2u, CLIUI_MOD_CTRL=4u, CLIUI_MOD_META=8u } CliUiModifier;
typedef enum { CLIUI_STYLE_DEFAULT=0, CLIUI_STYLE_KEYWORD=1, CLIUI_STYLE_STRING=2, CLIUI_STYLE_COMMENT=3, CLIUI_STYLE_NUMBER=4, CLIUI_STYLE_TYPE=5, CLIUI_STYLE_SYMBOL=6, CLIUI_STYLE_ERROR=7, CLIUI_STYLE_SELECTION=8, CLIUI_STYLE_STATUS=9 } CliUiStyleClass;

typedef struct { int rows, cols; } CliUiSize;
typedef struct { size_t start, length; CliUiStyleClass style; } CliUiStyleSpan;
typedef struct { size_t anchor, caret; } CliUiSelection;
typedef struct { CliUiKeyKind kind; uint32_t modifiers; uint32_t codepoint; unsigned function_number; } CliUiKeyEvent;
typedef enum { CLIUI_EVENT_KEY=1, CLIUI_EVENT_RESIZE=2, CLIUI_EVENT_FOCUS=3, CLIUI_EVENT_COMMAND=4 } CliUiEventKind;
typedef struct {
  CliUiEventKind kind;
  CliUiKeyEvent key;
  CliUiSize size;
  CliUiHandle target;
  const char *command;
} CliUiEvent;
typedef void (*CliUiDispatch)(void *ctx, const CliUiEvent *event);

typedef struct CliUiRenderer CliUiRenderer;

/* Host I/O is deliberately separate from ANSI semantics.  A provider may be
 * POSIX file descriptors, a Windows console/pipe host, a test harness, or a
 * NewShell Queue Fabric terminal endpoint.  The ANSI renderer never owns
 * process-global terminal mode. */
typedef struct {
  void *ctx;
  int (*write)(void *ctx, const unsigned char *bytes, size_t n);
  int (*read)(void *ctx, unsigned char *bytes, size_t cap, int timeout_ms, size_t *nread);
  void (*close)(void *ctx);
} CliUiIo;
typedef struct {
  uint32_t abi;
  void (*destroy)(CliUiRenderer *r);
  CliUiResult (*set_dispatch)(CliUiRenderer *r, CliUiDispatch fn, void *ctx);
  CliUiResult (*set_size)(CliUiRenderer *r, CliUiSize size);
  CliUiResult (*begin_frame)(CliUiRenderer *r);
  CliUiResult (*draw_text)(CliUiRenderer *r, int row, int col, const char *utf8, CliUiStyleClass style);
  CliUiResult (*draw_rule)(CliUiRenderer *r, int row, int col, int width, uint32_t glyph, CliUiStyleClass style);
  CliUiResult (*set_cursor)(CliUiRenderer *r, int row, int col, int visible);
  CliUiResult (*end_frame)(CliUiRenderer *r);
  CliUiResult (*poll)(CliUiRenderer *r, int timeout_ms);
} CliUiRendererVTable;
struct CliUiRenderer { const CliUiRendererVTable *v; void *impl; };

/* ANSI backend writes ECMA-48/ANSI escape sequences but never enables mouse
 * tracking, bracketed-paste capture, alternate-screen mode, or terminal-wide
 * selection interception. Native terminal copy/paste therefore remains owned
 * by the terminal unless the application explicitly edits its own document. */
CliUiRenderer *cliui_ansi_create_with_io(const CliUiIo *io);

/* POSIX convenience constructor.  Kept out of the semantic renderer core;
 * returns NULL on non-POSIX builds. */
CliUiRenderer *cliui_ansi_create(int input_fd, int output_fd);
CliUiResult cliui_ansi_feed(CliUiRenderer *r, const unsigned char *bytes, size_t n);

/* Optional provider. Returns NULL when built without a curses implementation. */
CliUiRenderer *cliui_curses_create(void);

#ifdef __cplusplus
}
#endif
#endif
