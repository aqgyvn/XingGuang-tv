#include "XGQuickJS.h"

#include "quickjs/quickjs.h"

#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <sys/time.h>

struct XGQuickJSContext {
    JSRuntime *runtime;
    JSContext *context;
    XGQuickJSBridgeCallback bridge;
    XGQuickJSModuleResolverCallback resolver;
    XGQuickJSModuleLoaderCallback loader;
    void *opaque;
    _Atomic int interrupted;
    int64_t deadline_ms;
    int promise_done;
    int promise_rejected;
    JSValue promise_value;
    char *last_error;
};

static int64_t xg_now_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static char *xg_strdup(const char *value) {
    size_t length;
    char *copy;
    if (!value) return NULL;
    length = strlen(value);
    copy = (char *)malloc(length + 1);
    if (!copy) return NULL;
    memcpy(copy, value, length + 1);
    return copy;
}

static char *xg_js_strdup(JSContext *ctx, const char *value) {
    size_t length;
    char *copy;
    if (!value) return NULL;
    length = strlen(value);
    copy = (char *)js_malloc(ctx, length + 1);
    if (!copy) return NULL;
    memcpy(copy, value, length + 1);
    return copy;
}

static void xg_clear_error(XGQuickJSContext *context) {
    free(context->last_error);
    context->last_error = NULL;
}

static void xg_set_error(XGQuickJSContext *context, const char *message) {
    xg_clear_error(context);
    context->last_error = xg_strdup(message ? message : "JavaScript 执行失败");
}

static void xg_set_exception(XGQuickJSContext *context) {
    JSValue exception;
    const char *message = NULL;
    JSValue stack = JS_UNDEFINED;

    exception = JS_GetException(context->context);
    if (JS_IsObject(exception)) {
        stack = JS_GetPropertyStr(context->context, exception, "stack");
        if (JS_IsString(stack)) {
            message = JS_ToCString(context->context, stack);
        } else if (JS_IsException(stack)) {
            JS_FreeValue(context->context, stack);
            stack = JS_UNDEFINED;
        }
    }
    if (!message) message = JS_ToCString(context->context, exception);
    xg_set_error(context, message ? message : "JavaScript 执行失败");
    if (message) JS_FreeCString(context->context, message);
    JS_FreeValue(context->context, stack);
    JS_FreeValue(context->context, exception);
}

static int xg_interrupt_handler(JSRuntime *runtime, void *opaque) {
    XGQuickJSContext *context = (XGQuickJSContext *)opaque;
    (void)runtime;
    return atomic_load(&context->interrupted) || (context->deadline_ms > 0 && xg_now_ms() >= context->deadline_ms);
}

static JSValue xg_bridge_call(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    XGQuickJSContext *context = (XGQuickJSContext *)JS_GetContextOpaque(ctx);
    const char *name;
    const char *payload;
    char *response;
    JSValue value;
    (void)this_val;

    if (!context || !context->bridge || argc < 1) return JS_UNDEFINED;
    name = JS_ToCString(ctx, argv[0]);
    payload = argc > 1 ? JS_ToCString(ctx, argv[1]) : "{}";
    if (!name || !payload) {
        if (name) JS_FreeCString(ctx, name);
        if (argc > 1 && payload) JS_FreeCString(ctx, payload);
        return JS_UNDEFINED;
    }
    response = context->bridge(name, payload, context->opaque);
    JS_FreeCString(ctx, name);
    if (argc > 1) JS_FreeCString(ctx, payload);
    if (!response) return JS_UNDEFINED;
    value = JS_ParseJSON(ctx, response, strlen(response), "xg-bridge");
    free(response);
    return value;
}

static JSValue xg_promise_resolve(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    XGQuickJSContext *context = (XGQuickJSContext *)JS_GetContextOpaque(ctx);
    (void)this_val;
    if (!context) return JS_UNDEFINED;
    JS_FreeValue(ctx, context->promise_value);
    context->promise_value = argc > 0 ? JS_DupValue(ctx, argv[0]) : JS_UNDEFINED;
    context->promise_done = 1;
    return JS_UNDEFINED;
}

static JSValue xg_promise_reject(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    XGQuickJSContext *context = (XGQuickJSContext *)JS_GetContextOpaque(ctx);
    const char *message = NULL;
    (void)this_val;
    if (!context) return JS_UNDEFINED;
    if (argc > 0) message = JS_ToCString(ctx, argv[0]);
    xg_set_error(context, message ? message : "JavaScript Promise 失败");
    context->promise_rejected = 1;
    if (message) JS_FreeCString(ctx, message);
    context->promise_done = 1;
    return JS_UNDEFINED;
}

static char *xg_value_to_string(JSContext *ctx, JSValueConst value) {
    const char *text;
    JSValue json;
    char *result;

    if (JS_IsUndefined(value) || JS_IsNull(value)) return xg_strdup("null");
    if (JS_IsString(value)) {
        text = JS_ToCString(ctx, value);
        result = xg_strdup(text ? text : "");
        if (text) JS_FreeCString(ctx, text);
        return result;
    }
    json = JS_JSONStringify(ctx, value, JS_UNDEFINED, JS_UNDEFINED);
    if (JS_IsException(json)) return NULL;
    text = JS_ToCString(ctx, json);
    result = xg_strdup(text ? text : "null");
    if (text) JS_FreeCString(ctx, text);
    JS_FreeValue(ctx, json);
    return result;
}

static int xg_run_jobs(XGQuickJSContext *context) {
    JSContext *job_context = NULL;
    int result;
    int count = 0;
    while (!context->promise_done && count++ < 10000) {
        result = JS_ExecutePendingJob(context->runtime, &job_context);
        if (result < 0) {
            if (atomic_load(&context->interrupted)) xg_set_error(context, "JavaScript 执行已取消");
            else xg_set_exception(context);
            return -1;
        }
        if (result == 0) break;
    }
    if (!context->promise_done && context->deadline_ms > 0 && xg_now_ms() >= context->deadline_ms) {
        xg_set_error(context, "JavaScript 执行超时");
        return -1;
    }
    return 0;
}

/* Module evaluation may enqueue jobs even when no promise is returned. */
static int xg_drain_jobs(XGQuickJSContext *context) {
    JSContext *job_context = NULL;
    int result;
    int count = 0;
    while (count++ < 10000) {
        result = JS_ExecutePendingJob(context->runtime, &job_context);
        if (result < 0) {
            xg_set_exception(context);
            return -1;
        }
        if (result == 0) return 0;
        if (atomic_load(&context->interrupted)) {
            xg_set_error(context, "JavaScript 执行已取消");
            return -1;
        }
        if (context->deadline_ms > 0 && xg_now_ms() >= context->deadline_ms) {
            xg_set_error(context, "JavaScript 执行超时");
            return -1;
        }
    }
    xg_set_error(context, "JavaScript 任务队列未完成");
    return -1;
}

static char *xg_quote(const char *value) {
    size_t length = strlen(value);
    size_t capacity = length * 2 + 3;
    size_t index;
    size_t output = 0;
    char *result = (char *)malloc(capacity);
    if (!result) return NULL;
    result[output++] = '"';
    for (index = 0; index < length; index++) {
        unsigned char character = (unsigned char)value[index];
        if (character == '"' || character == '\\') result[output++] = '\\';
        if (character == '\n') {
            result[output++] = '\\';
            result[output++] = 'n';
        } else if (character == '\r') {
            result[output++] = '\\';
            result[output++] = 'r';
        } else if (character == '\t') {
            result[output++] = '\\';
            result[output++] = 't';
        } else {
            result[output++] = (char)character;
        }
    }
    result[output++] = '"';
    result[output] = '\0';
    return result;
}

static int xg_install_prelude(XGQuickJSContext *context) {
    static const char prelude[] =
        "globalThis._http = function(url, options) {"
        " options = options || {};"
        " var response = __xg_bridge('req', JSON.stringify({url:url, options:options}));"
        " if (typeof options.complete === 'function') { options.complete(response); return null; }"
        " return response;"
        " };"
        "globalThis.local = { get:function(rule,key){ return __xg_bridge('local.get', JSON.stringify({rule:rule || '', key:key || ''})); },"
        " set:function(rule,key,value){ return __xg_bridge('local.set', JSON.stringify({rule:rule || '', key:key || '', value:value == null ? '' : String(value)})); },"
        " delete:function(rule,key){ return __xg_bridge('local.delete', JSON.stringify({rule:rule || '', key:key || ''})); } };"
        "globalThis.console = { log:function(){ __xg_bridge('console.log', JSON.stringify(Array.from(arguments))); },"
        " info:function(){ __xg_bridge('console.info', JSON.stringify(Array.from(arguments))); },"
        " warn:function(){ __xg_bridge('console.warn', JSON.stringify(Array.from(arguments))); },"
        " error:function(){ __xg_bridge('console.error', JSON.stringify(Array.from(arguments))); } };"
        "globalThis.joinUrl = function(parent, child) { return __xg_bridge('joinUrl', JSON.stringify({parent:parent, child:child})); };"
        "globalThis.s2t = function(value) { return __xg_bridge('s2t', JSON.stringify({value:String(value)})); };"
        "globalThis.t2s = function(value) { return __xg_bridge('t2s', JSON.stringify({value:String(value)})); };"
        "globalThis.md5X = function(value) { return __xg_bridge('md5X', JSON.stringify({value:String(value)})); };"
        "globalThis.aesX = function(mode, encrypt, input, inBase64, key, iv, outBase64) { return __xg_bridge('aesX', JSON.stringify({mode:mode, encrypt:encrypt, input:input, inBase64:inBase64, key:key, iv:iv, outBase64:outBase64})); };"
        "globalThis.rsaX = function(mode, pub, encrypt, input, inBase64, key, outBase64) { return __xg_bridge('rsaX', JSON.stringify({mode:mode, pub:pub, encrypt:encrypt, input:input, inBase64:inBase64, key:key, outBase64:outBase64})); };"
        "globalThis.getProxy = function(local) { return __xg_bridge('getProxy', JSON.stringify({local:!!local})); };"
        "globalThis.js2Proxy = function(dynamic, siteType, siteKey, url, headers) { return __xg_bridge('js2Proxy', JSON.stringify({dynamic:!!dynamic, siteType:siteType, siteKey:siteKey, url:url, headers:headers || {}})); };"
        "globalThis.setTimeout = function(fn, delay) { fn(); return 0; };";
    JSValue bridge = JS_NewCFunction(context->context, xg_bridge_call, "__xg_bridge", 2);
    JSValue global = JS_GetGlobalObject(context->context);
    JSValue result;
    JS_SetPropertyStr(context->context, global, "__xg_bridge", bridge);
    JS_FreeValue(context->context, global);
    result = JS_Eval(context->context, prelude, sizeof(prelude) - 1, "xg-prelude", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(result)) {
        JS_FreeValue(context->context, result);
        xg_set_exception(context);
        return -1;
    }
    JS_FreeValue(context->context, result);
    return 0;
}

static int xg_install_http_module(XGQuickJSContext *context) {
    char *source;
    JSValue result;
    if (!context->loader) return 0;
    source = context->loader("xg-lib://lib/http.js", context->opaque);
    if (!source) {
        xg_set_error(context, "无法加载内置 JavaScript HTTP 模块");
        return -1;
    }
    result = JS_Eval(context->context, source, strlen(source), "xg-http", JS_EVAL_TYPE_GLOBAL);
    free(source);
    if (JS_IsException(result)) {
        JS_FreeValue(context->context, result);
        xg_set_exception(context);
        return -1;
    }
    JS_FreeValue(context->context, result);
    return xg_drain_jobs(context);
}

static char *xg_module_normalize(JSContext *ctx, const char *base_name, const char *module_name, void *opaque) {
    XGQuickJSContext *context = (XGQuickJSContext *)opaque;
    char *host_value;
    char *normalized;
    (void)ctx;
    if (!context->resolver) return xg_js_strdup(ctx, module_name);
    host_value = context->resolver(base_name, module_name, context->opaque);
    if (!host_value) return NULL;
    normalized = xg_js_strdup(ctx, host_value);
    free(host_value);
    return normalized;
}

static JSModuleDef *xg_module_loader(JSContext *ctx, const char *module_name, void *opaque, JSValueConst attributes) {
    XGQuickJSContext *context = (XGQuickJSContext *)opaque;
    char *source;
    JSValue compiled;
    JSModuleDef *module;
    (void)attributes;
    if (!context->loader) {
        JS_ThrowReferenceError(ctx, "没有配置 JavaScript 模块加载器: %s", module_name);
        return NULL;
    }
    source = context->loader(module_name, context->opaque);
    if (!source) {
        JS_ThrowReferenceError(ctx, "无法加载 JavaScript 模块: %s", module_name);
        return NULL;
    }
    compiled = JS_Eval(ctx, source, strlen(source), module_name, JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    free(source);
    if (JS_IsException(compiled)) return NULL;
    module = JS_VALUE_GET_PTR(compiled);
    JS_FreeValue(ctx, compiled);
    return module;
}

XGQuickJSContext *xg_quickjs_create(
    XGQuickJSBridgeCallback bridge,
    XGQuickJSModuleResolverCallback resolver,
    XGQuickJSModuleLoaderCallback loader,
    void *opaque
) {
    XGQuickJSContext *context = (XGQuickJSContext *)calloc(1, sizeof(XGQuickJSContext));
    if (!context) return NULL;
    context->bridge = bridge;
    context->resolver = resolver;
    context->loader = loader;
    context->opaque = opaque;
    atomic_init(&context->interrupted, 0);
    context->runtime = JS_NewRuntime();
    if (!context->runtime) {
        free(context);
        return NULL;
    }
    context->context = JS_NewContext(context->runtime);
    if (!context->context) {
        JS_FreeRuntime(context->runtime);
        free(context);
        return NULL;
    }
    JS_SetContextOpaque(context->context, context);
    JS_SetInterruptHandler(context->runtime, xg_interrupt_handler, context);
    JS_SetModuleLoaderFunc2(context->runtime, xg_module_normalize, xg_module_loader, NULL, context);
    context->promise_value = JS_UNDEFINED;
    if (xg_install_prelude(context) != 0) {
        xg_quickjs_destroy(context);
        return NULL;
    }
    if (xg_install_http_module(context) != 0) {
        xg_quickjs_destroy(context);
        return NULL;
    }
    return context;
}

void xg_quickjs_destroy(XGQuickJSContext *context) {
    if (!context) return;
    if (context->context) {
        JS_FreeValue(context->context, context->promise_value);
        JS_FreeContext(context->context);
    }
    if (context->runtime) JS_FreeRuntime(context->runtime);
    xg_clear_error(context);
    free(context);
}

int xg_quickjs_load_spider(XGQuickJSContext *context, const char *module_name) {
    char *quoted;
    char *wrapper;
    size_t length;
    JSValue result;
    if (!context || !module_name) return -1;
    quoted = xg_quote(module_name);
    if (!quoted) {
        xg_set_error(context, "JavaScript 模块名称无效");
        return -1;
    }
    length = strlen(quoted) + 500;
    wrapper = (char *)malloc(length);
    if (!wrapper) {
        free(quoted);
        xg_set_error(context, "JavaScript 模块内存不足");
        return -1;
    }
    snprintf(wrapper, length,
             "import * as spider from %s;"
             "if (!globalThis.__JS_SPIDER__) {"
             "if (spider.__jsEvalReturn) { globalThis.req = http; globalThis.__JS_SPIDER__ = spider.__jsEvalReturn(); }"
             "else if (spider.default) { globalThis.__JS_SPIDER__ = typeof spider.default === 'function' ? spider.default() : spider.default; }"
             "}", quoted);
    free(quoted);
    result = JS_Eval(context->context, wrapper, strlen(wrapper), "xg-spider-loader", JS_EVAL_TYPE_MODULE);
    free(wrapper);
    if (JS_IsException(result)) {
        JS_FreeValue(context->context, result);
        xg_set_exception(context);
        return -1;
    }
    JS_FreeValue(context->context, result);
    context->promise_done = 1;
    return xg_drain_jobs(context);
}

char *xg_quickjs_call(XGQuickJSContext *context, const char *method, const char *arguments_json) {
    JSValue global;
    JSValue spider;
    JSValue function;
    JSValue arguments;
    JSValue result;
    JSValue then;
    JSValue resolve;
    JSValue reject;
    JSValue callbacks[2];
    char *argument_expression;
    size_t argument_length;
    uint32_t length;
    uint32_t index;
    JSValue length_value;
    char *output;

    if (!context || !method) return NULL;
    xg_clear_error(context);
    atomic_store(&context->interrupted, 0);
    context->promise_done = 1;
    context->promise_rejected = 0;
    JS_FreeValue(context->context, context->promise_value);
    context->promise_value = JS_UNDEFINED;
    global = JS_GetGlobalObject(context->context);
    spider = JS_GetPropertyStr(context->context, global, "__JS_SPIDER__");
    JS_FreeValue(context->context, global);
    if (JS_IsUndefined(spider) || JS_IsNull(spider)) {
        JS_FreeValue(context->context, spider);
        xg_set_error(context, "JavaScript Spider 尚未初始化");
        return NULL;
    }
    function = JS_GetPropertyStr(context->context, spider, method);
    if (!JS_IsFunction(context->context, function)) {
        JS_FreeValue(context->context, function);
        JS_FreeValue(context->context, spider);
        return xg_strdup("null");
    }
    if (!arguments_json) arguments_json = "[]";
    argument_length = strlen(arguments_json);
    argument_expression = (char *)malloc(argument_length + 3);
    if (!argument_expression) {
        xg_set_error(context, "JavaScript 鍙傛暟鍐呭瓨涓嶈冻");
        JS_FreeValue(context->context, function);
        JS_FreeValue(context->context, spider);
        return NULL;
    }
    argument_expression[0] = '(';
    memcpy(argument_expression + 1, arguments_json, argument_length);
    argument_expression[argument_length + 1] = ')';
    argument_expression[argument_length + 2] = '\0';
    arguments = JS_Eval(
        context->context,
        argument_expression,
        argument_length + 2,
        "xg-arguments",
        JS_EVAL_TYPE_GLOBAL
    );
    free(argument_expression);
    if (JS_IsException(arguments) || !JS_IsArray(context->context, arguments)) {
        if (JS_IsException(arguments)) {
            unsigned int byte0 = argument_length > 0 ? (unsigned char)arguments_json[0] : 0;
            unsigned int byte1 = argument_length > 1 ? (unsigned char)arguments_json[1] : 0;
            unsigned int byte2 = argument_length > 2 ? (unsigned char)arguments_json[2] : 0;
            unsigned int byte3 = argument_length > 3 ? (unsigned char)arguments_json[3] : 0;
            char diagnostic[256];
            char *exception_message;
            xg_set_exception(context);
            exception_message = xg_strdup(context->last_error);
            snprintf(
                diagnostic,
                sizeof(diagnostic),
                "%s [arguments length=%zu prefix=%02x%02x%02x%02x]",
                exception_message ? exception_message : "JavaScript 参数解析失败",
                argument_length,
                byte0,
                byte1,
                byte2,
                byte3
            );
            free(exception_message);
            xg_set_error(context, diagnostic);
        } else {
            xg_set_error(context, "JavaScript 参数必须是数组");
        }
        JS_FreeValue(context->context, arguments);
        JS_FreeValue(context->context, function);
        JS_FreeValue(context->context, spider);
        return NULL;
    }
    length_value = JS_GetPropertyStr(context->context, arguments, "length");
    if (JS_ToUint32(context->context, &length, length_value) < 0) length = 0;
    JS_FreeValue(context->context, length_value);
    JSValue *argv = (JSValue *)calloc(length ? length : 1, sizeof(JSValue));
    if (!argv) {
        xg_set_error(context, "JavaScript 参数内存不足");
        JS_FreeValue(context->context, arguments);
        JS_FreeValue(context->context, function);
        JS_FreeValue(context->context, spider);
        return NULL;
    }
    for (index = 0; index < length; index++) argv[index] = JS_GetPropertyUint32(context->context, arguments, index);
    result = JS_Call(context->context, function, spider, length, (JSValueConst *)argv);
    for (index = 0; index < length; index++) JS_FreeValue(context->context, argv[index]);
    free(argv);
    JS_FreeValue(context->context, arguments);
    JS_FreeValue(context->context, function);
    JS_FreeValue(context->context, spider);
    if (JS_IsException(result)) {
        if (atomic_load(&context->interrupted)) xg_set_error(context, "JavaScript 执行已取消");
        else xg_set_exception(context);
        JS_FreeValue(context->context, result);
        return NULL;
    }
    if (JS_IsObject(result)) {
        then = JS_GetPropertyStr(context->context, result, "then");
    } else {
        then = JS_UNDEFINED;
    }
    if (JS_IsException(then)) {
        xg_set_exception(context);
        JS_FreeValue(context->context, then);
        JS_FreeValue(context->context, result);
        return NULL;
    }
    if (JS_IsFunction(context->context, then)) {
        context->promise_done = 0;
        resolve = JS_NewCFunction(context->context, xg_promise_resolve, "xg-resolve", 1);
        reject = JS_NewCFunction(context->context, xg_promise_reject, "xg-reject", 1);
        callbacks[0] = resolve;
        callbacks[1] = reject;
        JSValue chained = JS_Call(context->context, then, result, 2, (JSValueConst *)callbacks);
        int chained_exception = JS_IsException(chained);
        if (chained_exception) xg_set_exception(context);
        JS_FreeValue(context->context, chained);
        JS_FreeValue(context->context, resolve);
        JS_FreeValue(context->context, reject);
        JS_FreeValue(context->context, then);
        JS_FreeValue(context->context, result);
        if (chained_exception) return NULL;
        if (xg_run_jobs(context) != 0 || context->promise_rejected) return NULL;
        if (!context->promise_done) {
            xg_set_error(context, "JavaScript Promise 未完成");
            return NULL;
        }
        result = JS_DupValue(context->context, context->promise_value);
    } else {
        JS_FreeValue(context->context, then);
    }
    output = xg_value_to_string(context->context, result);
    if (!output && !context->last_error) xg_set_exception(context);
    JS_FreeValue(context->context, result);
    return output;
}

void xg_quickjs_set_deadline(XGQuickJSContext *context, int64_t deadline_ms) {
    if (!context) return;
    context->deadline_ms = deadline_ms;
    atomic_store(&context->interrupted, 0);
}

void xg_quickjs_interrupt(XGQuickJSContext *context) {
    if (context) atomic_store(&context->interrupted, 1);
}

const char *xg_quickjs_last_error(const XGQuickJSContext *context) {
    return context && context->last_error ? context->last_error : "";
}

char *xg_quickjs_copy_string(const char *value) {
    return xg_strdup(value);
}

void xg_quickjs_free_string(char *value) {
    free(value);
}
