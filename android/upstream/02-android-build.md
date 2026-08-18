# Draft 2 — Android build of litert_lm_main fails in Rust

Target: `google-ai-edge/LiteRT-LM` issue. **Filed: [#3247](https://github.com/google-ai-edge/LiteRT-LM/issues/3247)** (2026-08-14, as john-rocky).
Environment: macOS arm64 host, NDK 28.2.13676358, Bazel 7.6.1, tag `v0.16.0`.

---

Thanks for keeping the Android path in the tree — being able to build
`litert_lm_main` for the device is what let us isolate a model issue to a single
variable today.

One snag worth recording: on a macOS arm64 host, `--config=android_arm64` fails
before it compiles anything of yours.

```
ERROR: external/rules_rust_ctve__thiserror-1.0.69/BUILD.bazel:14:13:
  Compiling Rust rlib thiserror v1.0.69 [for tool] failed
error[E0463]: can't find crate for `thiserror_impl`
```

Crates with a derive macro hit it (`thiserror`, `zerofrom`). The failing repos are
`rules_rust_ctve__*` — rules_rust's own vendored tool crates, separate from the
`crate_index__*` universe that `llguidance` pulls in (WORKSPACE:308); llguidance
is just why Rust is in the graph at all. `--extern` is passed correctly and the
dylib on disk is a valid arm64 proc-macro — `nm` shows
`__rustc_proc_macro_decls_*` — so rustc is failing to load a file that looks
right.

**One flag fixes it:**

```bash
bazelisk build //runtime/engine:litert_lm_main \
  --config=android_arm64 --enable_platform_specific_config
```

`.bazelrc:244` has `build:android --noenable_platform_specific_config`, which
stops `build:macos` from applying to the host configuration. Re-enabling it makes
the whole target build — 2390 actions here — and the resulting binary runs on a
Pixel 8a.

On one run the loader reported `dlopen: … mis-aligned LINKEDIT string pool` on the
proc-macro dylib, which would explain the symptom — I have not managed to
reproduce that message on demand since, so I'd rather offer it as a lead than
state it as the mechanism.

Nothing is blocked on our side now that the flag is known. Flagging it because
the failure points at `rules_rust` rather than at a config flag, which is a slow
place to start looking.
