# Prompt design notes (small models)

The live prompt lives in `harness/Sources/JSProbeCore/Prompt.swift` and is emitted by
`jsprobe prompt --task <file>`. This file records *why* it is shaped the way it is.

Design choices, all aimed at 0.8B–2B models:

- **Short rules beat long rules.** Small models follow a 5-line rule list far more
  reliably than a paragraph. The system prompt is 5 bullets.
- **One code block, exact name, don't call it.** The single most common failure at this
  size is emitting prose + multiple partial snippets, or calling the function / adding a
  `console.log(...)` demo that throws. The prompt forbids all three explicitly.
- **State the sandbox.** "no network, no files, no imports, no async" pre-empts the model
  reaching for `require`, `fetch`, `fs`, or `await`, which would be define errors.
- **Signature echo.** Repeating the exact `function name(args)` signature in the user turn
  anchors the entry-point name so the harness can find it.

The extractor (`jsprobe extract`) is deliberately forgiving because even with these rules
small models leak: it accepts a ```js block, a ```javascript block, a bare ``` fence, or
no fence at all (falling back to `function <entry>` … last `}`). Extraction robustness is
part of measuring the *model*, not the *prompt-wrangling* — we don't want to score a model
as failing when it wrote correct JS but forgot the language tag.

If Phase B shows systematic format failures (define errors dominating over logic errors),
that is itself a finding: it argues for a constrained-decoding / grammar approach on
device, not a bigger model.
