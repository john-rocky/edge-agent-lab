#include "cjswatchdog.h"
#include <stdbool.h>

// Private JSC API: exported from the JavaScriptCore binary but not declared in the
// public Swift module map. Forward-declared here so we can link against it.
typedef bool (*CJSShouldTerminate)(JSContextRef ctx, void *userData);
extern void JSContextGroupSetExecutionTimeLimit(JSContextGroupRef group, double limit,
                                                CJSShouldTerminate callback, void *userData);

// Returning true tells JSC to terminate the over-budget evaluation. (Returning
// false would grant another `limit` seconds; we never want that here.)
static bool always_terminate(JSContextRef ctx, void *userData) {
    (void)ctx;
    (void)userData;
    return true;
}

void cjs_set_time_limit(JSContextGroupRef group, double seconds) {
    JSContextGroupSetExecutionTimeLimit(group, seconds, always_terminate, 0);
}
