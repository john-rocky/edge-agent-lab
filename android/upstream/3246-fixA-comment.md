# Comment for LiteRT-LM #3246 — offering the runtime-side fix

Status: **drafted, not posted.** Awaiting the user's go-ahead.

Target: https://github.com/google-ai-edge/LiteRT-LM/issues/3246
Account: john-rocky

The patch itself is `upstream/fixA-adapter-input-rows.patch`, verified in
FINDINGS.md ("Fix A: built and verified"). It is pasted inline below because
this repository is not published yet (naming gate), so there is nothing to link.

---

## English

Thanks for taking this one on. I have now built and measured the runtime-side
fix, in case having it in hand is useful.

With it, an **unmodified** `litert-community/LFM2.5-VL-450M_int4` bundle reads
all sixteen bands of the ruler fixture (`1…16`; before the fix, `1 2 3 4`
repeated), and an unmodified 3B grounds "Notifications" at `[500, 551]` instead
of folding everything into the top quarter of the screen. I would be glad to
send this as a PR in whatever form is easiest for you to import, or to leave it
here as a diff if you would rather write it yourselves.

The shape of the change is to keep `num_patches` as the number of tokens the
adapter *emits*, and to compute separately the number of encoder rows it
*consumes*:

- The masked path is untouched. Where the encoder emits a mask, the mask already
  says how many rows carry an image, so the new code is skipped entirely.
- Encoders that perform the shrink themselves come out unchanged: their adapter
  input buffer is the smallest of the three terms, so the `min` returns exactly
  the previous value.
- The write is now bounded by both buffer sizes, which the previous expression
  was not.

Built against v0.16.0 (`924e79c9`), macOS arm64, CPU backend, greedy decoding.

One thing I could not check: there is no ViT-family bundle on this machine, so
"unchanged for those models" above is an argument from the shapes rather than a
measurement. If you have one handy it would be worth a run.

```diff
     // `num_patches` counts the tokens the adapter will *emit*. The rows it has
     // to *consume* are the same number only when the encoder performs the
     // spatial shrink itself. When the shrink lives in the adapter instead —
     // LFM2 VL pools 2x2 patches inside its multi_modal_projector — the adapter
     // takes several encoder rows per output token, so writing `num_patches`
     // rows leaves the rest of its input at zero and the image is silently
     // cropped to its first rows.
     //
     // Where the patch count was derived from the input tensor, feed the encoder
     // rows that input actually produced, bounded by both buffers. For an
     // encoder that shrinks, the adapter's input buffer is the bound and this is
     // exactly the previous behaviour. The masked path is left alone: there the
     // mask already states how many rows carry an image.
     int num_encoder_rows = num_patches;
     if (!mask_index.HasValue()) {
       LITERT_ASSIGN_OR_RETURN(auto adapter_input_tensor_type,
                               adapter_input_buffers[0].TensorType());
       const auto& adapter_input_dims =
           adapter_input_tensor_type.Layout().Dimensions();
       const int adapter_input_rows =
           adapter_input_dims.size() >= 2
               ? adapter_input_dims[adapter_input_dims.size() - 2]
               : num_patches;
       const int encoder_output_rows =
           encoder_output_dim > 0
               ? encoder_output_num_elements / encoder_output_dim
               : num_patches;
       num_encoder_rows = std::min(
           {num_patches_from_input, adapter_input_rows, encoder_output_rows});
     }
 
     adapter_input_buffers[0].Clear();
     LITERT_RETURN_IF_ERROR(adapter_input_buffers[0].Write<float>(absl::MakeSpan(
-        encoder_output_data.data(), num_patches * encoder_output_dim)));
+        encoder_output_data.data(), num_encoder_rows * encoder_output_dim)));
```

Thanks again — whatever you decide here works for us.

---

## 日本語

この件を拾ってくださってありがとうございます。ランタイム側の修正をビルドして
測定まで済ませたので、手元にあると使いやすければどうぞ。

これを当てると、**未修正の** `litert-community/LFM2.5-VL-450M_int4` が定規
フィクスチャの 16 本すべてを読みます(`1…16`。修正前は `1 2 3 4` の繰り返し)。
未修正の 3B は "Notifications" を `[500, 551]` に接地し、画面上部 1/4 に畳み
込まれなくなります。取り込みやすい形で PR を出しますし、そちらで書かれる方が
早ければこの diff を置いておくだけでも構いません。

変更の形は、`num_patches` を adapter が *出す* トークン数のまま残し、adapter が
*受け取る* encoder 行数を別に求める、というものです。

- mask 経路は触っていません。encoder が mask を出す場合、何行が画像かは mask が
  すでに述べているので、新しいコードは丸ごとスキップされます。
- shrink を encoder 自身が行うモデルは値が変わりません。3 項のうち adapter の
  入力バッファが最小になるため、`min` は従来値をそのまま返します。
- 書き込みが両方のバッファサイズで抑えられます。従来の式にはこの境界が
  ありませんでした。

v0.16.0(`924e79c9`)に対してビルド、macOS arm64、CPU バックエンド、greedy。

1 点だけ確認できていません。この機に ViT 系のバンドルがないため、上の
「これらのモデルでは変わらない」は形状からの論証であって実測ではありません。
お手元にあれば一度回す価値があると思います。

(diff は英文側と同じ)

改めてありがとうございます。どう判断されても私たちの側は問題ありません。
