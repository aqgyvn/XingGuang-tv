#ifndef XG_QUICKJS_H
#define XG_QUICKJS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct XGQuickJSContext XGQuickJSContext;

/* Callback results must be heap allocated; QuickJS frees them with free(). */
typedef char *(*XGQuickJSBridgeCallback)(const char *name, const char *payload, void *opaque);
typedef char *(*XGQuickJSModuleResolverCallback)(const char *base_name, const char *module_name, void *opaque);
typedef char *(*XGQuickJSModuleLoaderCallback)(const char *module_name, void *opaque);

XGQuickJSContext *xg_quickjs_create(
    XGQuickJSBridgeCallback bridge,
    XGQuickJSModuleResolverCallback resolver,
    XGQuickJSModuleLoaderCallback loader,
    void *opaque
);

void xg_quickjs_destroy(XGQuickJSContext *context);

int xg_quickjs_load_spider(XGQuickJSContext *context, const char *module_name);
char *xg_quickjs_call(
    XGQuickJSContext *context,
    const char *method,
    const char *arguments_json,
    size_t arguments_length
);

void xg_quickjs_set_deadline(XGQuickJSContext *context, int64_t deadline_ms);
void xg_quickjs_interrupt(XGQuickJSContext *context);

const char *xg_quickjs_last_error(const XGQuickJSContext *context);
char *xg_quickjs_copy_string(const char *value);
void xg_quickjs_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif
