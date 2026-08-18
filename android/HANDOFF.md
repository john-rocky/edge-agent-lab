# edge-agent-lab — 立ち上げ手引き(2026-08-14 作成、コールドスタート用)

**何のレーンか**: LiteRT エージェント(cool demo + SDK)。採用の経緯・空棚の位置・3フェーズ計画の正 =
`~/code/standup/state/seeds.md` の「LiteRT エージェント lane」項。

## 土台(ローカルにある物)

- `~/code/litertlm-chat-android` — 公開済み Android チャットアプリ(image input、official Maven AAR、
  Bazel 9)。hybrid VLM(LFM2.5-VL)で画像が通る唯一のアプリ。Phase 1 はこれの改造から。
- `~/code/litert-lm-0160-android` — 0.16.0 Android ビルド作業場(AAR まわり)。
- LFM2.5-VL 変換 3/3 出荷済み(08-13)。変換の詳細 = `~/code/litertlm-convert/lfm25vl_work/RESULTS.md`
  と handoffs/2026-08-13-lfm25-vl-conversion.md。64k系 shape/count の engine 内部残差あり(変換シロ確定)。

## 状態(2026-08-14 スパイク後)

**全 Phase 完了**(1: 座標 / 2: 実タップ / 2.5: 複数ステップ / 3: SDK 切り出し)。
中間層は `//sdk:screen_agent`(`com.edgeagent.sdk`)。MediaProjection にもアクセシビリティにも依存せず、
`ScreenSource` と `ActionExecutor` を渡せば動く。アプリはその host。使い方 = `sdk/README.md`。
Bazel の workspace はリポジトリ root へ移動(ビルドは `bazelisk build //app:screen_grounding ...`)。
目標 1 つで複数ステップ自走(`Agent.kt`)。
「通知履歴を開く」= Settings → Notifications → Notification history を 2 ステップで到達、
3 歩目の空振りを画面変化ガードが停止(2026-08-15)。まとめ動画 = `demo/screen_agent_demo.mp4`。
スクショ → ローカル VL → タップ座標 → **実際にタップ**まで Pixel 8a で動作。
「Notifications 行を指して」→ `[500,563]` → タップ → Settings が SubSettings へ遷移(2026-08-15 確認)。
1 ステップ 14〜23 秒(キャッシュ温まり後は 12 秒台)、3B int4 CPU、画面キャプチャ同意はセッション 1 回。
実機録画 = `demo/phase2_accessibility.mp4`(41 秒・無編集・PII なし)。
**要注意の挙動**: 対象が画面に無くても `[]` を返さず捏造する / 見た目の似た隣接要素を取り違える。
どちらも Mac CLI で同一再現(モデル側の性質)。詳細 = FINDINGS.md 末尾。
途中でランタイム欠陥を 1 件掘り当てて変換側で修正済み。
詳細 = [FINDINGS.md](FINDINGS.md) と [DESIGN.md](DESIGN.md)。
**上位モデルで洗い直す場合は [REVIEW_BRIEF.md](REVIEW_BRIEF.md) から**(確度の内訳・未検証項目・誤診 2 件の記録)。

- LiteRT-LM 0.16.0 は LFM2.5-VL に**画像の上 1/4 しか渡していなかった**。root cause:
  runtime が `shrink = encoder入力patch数 / adapter出力token数` = 4 と算出し、adapter の
  1024 行入力に 256 行しか書かない。LFM2-VL は pixel-unshuffle が adapter 側にあるため
  この前提が崩れる。v0.16.0 ソース + 出荷 tflite 形状の両方で確認済み。
- 修正 B(export 側で pixel-unshuffle を encoder へ移す)を実装・検証済み。ランタイム無改造で
  **3B が 2/10 → 10/10**(torch コントロールと一致)。旧 image gate も 5/5 で回帰なし。
  450M の RESULTS.md 積み残し fingerprint(circle→"Square.")も同時に解消。
  成果物 = `~/code/litertlm-convert/lfm25vl_work/out_fixb/`。
- Android アプリ `app/`(パッケージ `com.edgeagent.lab`)**実機動作確認済み**(Pixel 8a)。
  MediaProjection → Framing → Grounding → オーバーレイが 1 周 8〜9.4 秒、エンジン load 27〜30 秒
  (1.6B int4、text-GPU + vision-CPU)。使い方 = `app/README.md`。
- **修正 B は Android AAR でも有効**: 実機キャプチャした ruler を `1…16` 全部読む(未修正は 4 まで)。
- **グラウンディングは 3B 専用能力**。450M / 1.6B は修正前後とも座標が丸め値(0/100/200/500)
  しか出ない。1.6B も fix B 済みだが座標は使えない。デモは 3B int4 + CPU。1 ターン 24 秒。
- **「2 つめの欠陥」は誤診でした。原因は自作アプリのコンテンツ順序**。
  `Content.Text` → `Content.ImageFile` の順だと実機グラウンディングが壊れます。画像を先に置くと直ります。
  `litert-lm run --attachment` は画像をテキストの前に置くため、Mac のコントロールは常に画像先行でした。
  修正後は Mac と一致(search bar `[500,99]` / Notifications `[500,551]` /
  Sound & vibration `[367,628]` / Storage `[558,981]`、全部正解)。
  テキスト先行でも説明・列挙・OCR は正常に動くので、captioning では気づけません。座標だけが静かに壊れます。
- 実機ストレージは解決(/data/local/tmp の旧テスト成果物 29 GB を削除、空き 26 GB)。
  3B は **CPU なら動く / GPU はプロセスが死ぬ**(8 GB 機)。3B の cache は 3.9 GB 使う
  (1.6B は 172 KB)。RESULTS.md の「GPU キャッシュ数 GB」は 3B 規模では正しい。
- **上流に 3 本起票済み**(2026-08-14、john-rocky): [#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246) truncation /
  [#3247](https://github.com/google-ai-edge/LiteRT-LM/issues/3247) Android ビルド / [#3248](https://github.com/google-ai-edge/LiteRT-LM/issues/3248) コンテンツ順序ドキュメント。本文は `upstream/`。
- **カード修正を 3 リポジトリに反映済み**(2026-08-14): Known issue ブロック + #3246 参照。
  450M / 1.6B は「モデルが小さいせい」という**誤った因果説明を撤回**(実際はランタイム欠陥。
  修正すると 450M の shape が Square.→Circle. に変わる)。「3B なら細かい視覚推論ができる」も撤回
  (3B も同一の欠陥。5/5 なのは全体文脈から答えているため)。手順と本文 = `cards/`。
- **重みは差し替えていない**。#3246 の修正方法次第で修正版バンドルの方が壊れうるため保留。理由は
  `cards/CARD_CORRECTIONS.md`。
- **SDK 切り出し済み**(Phase 3): `sdk/`(`//sdk:screen_agent`)。中身 = Seams / Framing /
  Grounding / LiteRtGrounder / Agent / ScreenAgent / ScreenFrames。MediaProjection と
  アクセシビリティはライブラリに入れず、`ScreenSource` と `ActionExecutor` として host に渡す。
  抽出後に Point と Agent を実機で再確認済み(2026-08-15、通知履歴 2 ステップ到達 + 停止)。
- **修正 A(runtime 側)もビルド・検証済み**(2026-08-15)。patch = `upstream/fixA-adapter-input-rows.patch`
  (v0.16.0 `924e79c9` に対して 31 行、1 関数)。作業場 = `~/code/litert-lm-0160-android`
  (このファイルを改変した状態で置いてある。ビルドは
  `bazelisk build //runtime/engine:litert_lm_main -c opt --enable_platform_specific_config`)。
  **未修正バンドルのまま** 450M が rows16 を `1…16`、3B が Notifications を `[500,551]` に接地。
  mask 経路は不変・shrink する encoder も値不変(min の最小項が adapter 入力バッファ)。
  ViT 系バンドルが手元に無く、そこだけ実測できていない。#3246 へのコメント草稿 =
  `upstream/3246-fixA-comment.md`(**未投稿**)。
- **エージェントのキャラクター(バッジ)を実装**。`AgentFace`(Canvas 描画、画像アセット無し)+
  `AgentOverlay`(`TYPE_APPLICATION_OVERLAY`)。他アプリの上に浮き、状態で色と目が変わる
  (見る=青 / 考える=瞳が細まる / 押す=緑 + 波紋 / 完了=笑った目 / 打ち切り=橙)。
  **押すときは丸く縮んでその座標まで歩き、押してから戻る**(`ShownExecutor` が
  `ActionExecutor` を包むだけ。SDK は無変更)。
  キャプチャ中はモデルに写らないよう自分を隠す。
  **設定アプリのホーム画面の上には出ない**(`HIDE_NON_SYSTEM_OVERLAY_WINDOWS`。詳細 = FINDINGS.md)。
  デモは電卓など別アプリから始めること(設定なら SubSettings 以下なら出る)。
  アプリ本体の見出しにも同じ顔がいて、**打った内容を読み返して返事する**(モードで文面が変わる)。
  **キャラは動画側にも同じ描画コードで出る**(`tools/demo_robot.py` を Kotlin と PIL の両方で使用)。
  既知の穴: 画面変化ガードは電卓の数字 1 文字を「変化なし」と読む(FINDINGS.md 末尾)。
- **tap 以外の操作を実装・実機確認済み**(scroll / back / 文字入力、2026-08-15)。
  4 つとも Pixel 8a で動作: scroll → tap で About phone 到達、back で検索画面離脱、
  Settings 検索窓に `wifi` を入力(目標文から抽出)。`Agent.operate` が
  「何をするか」を先に聞き(`Planning`、自前プロンプト)、座標が要る時だけ
  ベンダーの grounding プロンプトを叩く。1 ステップ最大 2 回のモデル呼び出し。
  UI は 5 つ目のモード **Act**。文字入力だけは `canRetrieveWindowContent` が要る
  (ジェスチャでは文字を入れられない)。入力フォーカス中のノードに書くだけで、
  ツリーは読まない。理由は DESIGN.md。プランナ側で判明した 3B の癖
  (プレースホルダ丸写し / 例文の値の丸写し / 未知動詞)と、
  フォーカスとキーボードの罠は FINDINGS.md 末尾。
  デモ動画 = `demo/screen_agent_demo.mp4`(**16:9 / 1920×1080 / 130 秒**)。作りの規則が 8 つある。
  (-4) **説明するのは仕組みであって挙動ではない**。「スクショを入れる → プロンプトで
  切る → 座標が返る → 画素に直して押す」が主題。バッジが歩くのは UI の演出であって
  仕組みではないので、説明からは外した(アプリには残っている)。
  中心の 1 枚は、実スクショに**モデルが実際に返した座標をプロットした**カード。
  (-3) **横長**。実機の画面を左に立て、説明を右に並べる。縦長では 1 列に押し込まれて
  「実機を見る」と「説明を読む」が交互待ちになっていた。
  (-2) **Part 3 は 1 回の実行を全部トレースする**。ステップごとに、モデルに渡した実スクショ・
  送ったプロンプト本文・返ってきた JSON・実行した操作を、logcat の時刻付きで出す。
  素材 = `demo/phase3_act_loop.mp4`(この実行の無編集録画)。
  (-1) **図解は実装内部ではなく、やり取りの列**。何を送り(画像+プロンプト)、何が返り(JSON)、
  何をしたか(座標→タップ)を毎回の turn として見せる。解像度やパッチ数は出さない。
  (0) **各パートの頭にアプリ UI そのものを出す**(目標を打つ欄と RUN ボタン、モードのラジオ)。
  指示を出す人間の側が見えないと、端末が勝手に動いているようにしか見えない。
  (1) **実機映像はベゼル枠 + 赤ドット、図解は青の全画面**。見た目を混ぜない。
  (2) **待ち時間 7 か所すべてに 1 つずつ図解を割り当てる**。静止画の早送りは無し。
  (3) 全フレームに **capture · frame · encode · decode · act の 5 段レール**を出し、
  現在地を光らせる。待ちの実秒と倍率は出したまま。
  素の記録は `demo/phase3_act_loop.mp4`(Act 1 回分、無編集・実時間 151 秒)。
  **作り直しは `tools/demo_build2.py`**(共通部品 = `demo_chrome.py`、図解 = `demo_beats.py`、
  キャラ = `demo_robot.py`)。**動画に出るプロンプトは `tools/demo_prompts.py` が
  Kotlin ソースから直接抜き出す**ので、コードを変えれば動画も変わる(書き写しではない)。
  日本語の確認用コピー = `demo/screen_agent_demo_ja.mp4`(`DEMO_LANG=ja` でビルド)。
  **解説もプロンプトも日本語**(訳であることを画面に明記)。モデルの返答 JSON と
  logcat の時刻だけは証拠なので英語の原文のまま。
  尺の配分: 実機ショットは変化の瞬間だけ 3 秒台、図解は 10〜14.5 秒。
  **実機は常に中央・最大**(450×1000)。文言は左の空きに置く。拡大の帯は
  「全体のどこか」が分からず却って混乱するのでやめた。
  **説明は文章ではなく図**: (1) 4 箱のパイプライン(画像+プロンプト → モデル →
  座標 → 押下。実スクショに実座標をプロット)、(2) ビューツリー方式との対比図、
  (3) ループの循環図(変化した→もう一周 / 同一→停止)。
  プロンプト単体の箱は作らない — モデルへの入力は画像と文面で 1 つだから。
  **見出しは抽象ラベルではなく具体的な主張**にする(「ループとその終わり方」ではなく
  「画面が変わらなくなったら止まる。」)。副題は使わず、言いたいことを見出しにする。
  画面が語っていることを字幕で繰り返さない(plain-writing の cut pass)。
  待ちは切らずに早送りし、倍率と実秒を字幕に焼く。倍率は setpts と同じ値から
  生成しているので、表示と実際がずれない。

## 3 フェーズ計画(全部完了)

スクリーンショット → ローカル VL(LFM2.5-VL)→ タップ座標 grounding → オーバーレイ(Phase 1)、
アクセシビリティで実タップ(Phase 2)、目標 1 つで自走(Phase 2.5)、SDK 切り出し(Phase 3)。
LFM2.5-VL は ScreenSpot-v2 80.7 が売り(発表値)= 画面接地はモデルの得意技。
tool registry は未実装(非目標)。FunctionGemma 270M(公式、NL→function call)は部品候補のまま。

## 制約(必読)

- **naming/公開ゲート**: litert- prefix は Space の side-project 相談(08-12 投稿、返答待ち)の範囲。
  返答まで本リポは中立名のまま、GitHub 公開もしない。
- 発信は実機動画標準(seeds.md 参照)。クロスランタイム比較数値の公開は Gemma-4 のみ。
- LiteRT チーム最優先の序列は不変 — このレーンは 7b 別枠。
