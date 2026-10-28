#include <oorexxapi.h>
#include <string.h>
#include <stdlib.h>
#include "oorexx_cli_ui.h"

typedef struct {
    CliUiRenderer *renderer;
    CliUiEvent event;
    int has_event;
} RexxCliUiAnsi;

static void capture_event(void *ctx, const CliUiEvent *event)
{
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)ctx;
    bridge->event = *event;
    bridge->has_event = 1;
}

RexxRoutine2(POINTER, CliUiAnsiOpen, int, inputFd, int, outputFd)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)calloc(1, sizeof(*bridge));
    if (bridge == NULL) return NULL;
    bridge->renderer = cliui_ansi_create(inputFd, outputFd);
    if (bridge->renderer == NULL) { free(bridge); return NULL; }
    bridge->renderer->v->set_dispatch(bridge->renderer, capture_event, bridge);
    return bridge;
}

RexxRoutine1(int, CliUiAnsiClose, POINTER, handle)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return CLIUI_EINVAL;
    bridge->renderer->v->destroy(bridge->renderer);
    free(bridge);
    return CLIUI_OK;
}

RexxRoutine3(int, CliUiAnsiResize, POINTER, handle, int, rows, int, cols)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return CLIUI_EINVAL;
    CliUiSize size = { rows, cols };
    return bridge->renderer->v->set_size(bridge->renderer, size);
}

RexxRoutine1(int, CliUiAnsiBeginFrame, POINTER, handle)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return CLIUI_EINVAL;
    return bridge->renderer->v->begin_frame(bridge->renderer);
}

RexxRoutine5(int, CliUiAnsiDrawText, POINTER, handle, int, row, int, col, CSTRING, text, int, style)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return CLIUI_EINVAL;
    return bridge->renderer->v->draw_text(bridge->renderer, row, col, text, (CliUiStyleClass)style);
}

RexxRoutine4(int, CliUiAnsiSetCursor, POINTER, handle, int, row, int, col, int, visible)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return CLIUI_EINVAL;
    return bridge->renderer->v->set_cursor(bridge->renderer, row, col, visible);
}

RexxRoutine1(int, CliUiAnsiEndFrame, POINTER, handle)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return CLIUI_EINVAL;
    return bridge->renderer->v->end_frame(bridge->renderer);
}

static const char *key_name(CliUiKeyKind kind)
{
    switch (kind) {
        case CLIUI_KEY_UP: return "UP"; case CLIUI_KEY_DOWN: return "DOWN";
        case CLIUI_KEY_LEFT: return "LEFT"; case CLIUI_KEY_RIGHT: return "RIGHT";
        case CLIUI_KEY_HOME: return "HOME"; case CLIUI_KEY_END: return "END";
        case CLIUI_KEY_PAGE_UP: return "PAGE_UP"; case CLIUI_KEY_PAGE_DOWN: return "PAGE_DOWN";
        case CLIUI_KEY_ENTER: return "ENTER"; case CLIUI_KEY_ESCAPE: return "ESCAPE";
        case CLIUI_KEY_TAB: return "TAB"; case CLIUI_KEY_BACKTAB: return "BACKTAB";
        case CLIUI_KEY_BACKSPACE: return "BACKSPACE"; case CLIUI_KEY_DELETE: return "DELETE";
        case CLIUI_KEY_FUNCTION: return "FUNCTION"; case CLIUI_KEY_TEXT: return "TEXT";
        default: return "UNKNOWN";
    }
}

RexxRoutine2(RexxObjectPtr, CliUiAnsiPollKey, POINTER, handle, int, timeoutMs)
{
    (void)context;
    RexxCliUiAnsi *bridge = (RexxCliUiAnsi *)handle;
    if (bridge == NULL) return context->Nil();
    bridge->has_event = 0;
    bridge->renderer->v->poll(bridge->renderer, timeoutMs);
    if (!bridge->has_event || bridge->event.kind != CLIUI_EVENT_KEY) return context->Nil();
    RexxArrayObject value = context->NewArray(4);
    context->ArrayPut(value, context->String(key_name(bridge->event.key.kind)), 1);
    context->ArrayPut(value, context->UnsignedInt32(bridge->event.key.modifiers), 2);
    context->ArrayPut(value, context->UnsignedInt32(bridge->event.key.codepoint), 3);
    context->ArrayPut(value, context->UnsignedInt32(bridge->event.key.function_number), 4);
    return value;
}

RexxRoutineEntry cliui_routines[] = {
    REXX_TYPED_ROUTINE(CliUiAnsiOpen, CliUiAnsiOpen),
    REXX_TYPED_ROUTINE(CliUiAnsiClose, CliUiAnsiClose),
    REXX_TYPED_ROUTINE(CliUiAnsiResize, CliUiAnsiResize),
    REXX_TYPED_ROUTINE(CliUiAnsiBeginFrame, CliUiAnsiBeginFrame),
    REXX_TYPED_ROUTINE(CliUiAnsiDrawText, CliUiAnsiDrawText),
    REXX_TYPED_ROUTINE(CliUiAnsiSetCursor, CliUiAnsiSetCursor),
    REXX_TYPED_ROUTINE(CliUiAnsiEndFrame, CliUiAnsiEndFrame),
    REXX_TYPED_ROUTINE(CliUiAnsiPollKey, CliUiAnsiPollKey),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry CliUiAnsi_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "CliUiAnsi",
    "0.1.7",
    NULL, NULL, cliui_routines, NULL
};
OOREXX_GET_PACKAGE(CliUiAnsi);
