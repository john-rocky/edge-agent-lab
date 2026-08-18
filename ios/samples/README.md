# iOS samples

1. **lfm-tools-ios** — 54-tool agent demo behind Apple's `LanguageModel`
   protocol; the same session runs Apple's on-device model or LFM2.5 via
   LiteRT-LM. Hosts every scenario pack (`--scenario photo|focus|report`),
   the bench runner (`--toolbench --toolset …`), and voice input (a mic in
   the composer; `--voice` on the stage takes each beat from the
   microphone instead of the script). It lives in
   [LiteRT-Models](https://github.com/john-rocky/LiteRT-Models/tree/screen-agent/lfm-tools-ios)
   while the benchmark here takes shape; it then migrates or stays linked.

The adapter behind it:
[LiteRT-LM branch `apple-fm-guided-constrained-decoding`](https://github.com/john-rocky/LiteRT-LM/tree/apple-fm-guided-constrained-decoding)
— `LiteRTLanguageModel`, tool calling with guided decoding, thinking-budget
control, bare/OpenAI tool-list styles.
