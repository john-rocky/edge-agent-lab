#pragma once
#include <JavaScriptCore/JavaScriptCore.h>

// Install a per-evaluation execution-time watchdog on a JSContextGroup. Any single
// script evaluation that runs longer than `seconds` is terminated (surfacing as a
// "JavaScript execution terminated." exception). This wraps a private JSC API that
// is exported from the framework binary but absent from the public Swift module,
// so it must be reached through C.
void cjs_set_time_limit(JSContextGroupRef group, double seconds);
