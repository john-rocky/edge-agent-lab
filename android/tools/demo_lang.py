#!/usr/bin/env python3
"""A Japanese review copy of the demo.

The commentary *and* the prompts are translated, because a reviewer who cannot
read the prompt cannot review it. Every card that carries a translated prompt
says so, and the model's own replies and the logged timestamps are left exactly
as recorded — those are evidence, not prose.

Switching on is a whole-module swap: `apply()` replaces the two Latin fonts with
a Japanese face and wraps `ImageDraw.text` so any string with an entry below is
drawn translated. A string with no entry is drawn untouched, which is what keeps
the prompts safe by construction.
"""
from PIL import ImageDraw, ImageFont

import demo_chrome

JA_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
JA_REG = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"
# No CJK monospace ships with macOS, so the prompt bodies use the same face as
# the prose. JSON keeps its shape well enough to read; alignment is the cost.
JA_MONO = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"

TEXT = {
    # cards

    # mechanism-first rewrite
    "A screenshot goes in. Coordinates come out.":
        "スクリーンショットを入れると、座標が返る。",
    "Five boxes, and nothing in between them.": "箱は 5 つ。間には何もありません。",
    "1 · SCREENSHOT": "1 · スクショ", "2 · PROMPT": "2 · プロンプト",
    "3 · MODEL": "3 · モデル", "4 · ANSWER": "4 · 返答", "5 · PRESS": "5 · 押す",
    "1080 × 2400, as captured": "1080 × 2400、撮ったまま",
    "the vendor's wording, verbatim": "ベンダーの文面そのまま",
    "runs on the phone": "端末上で動く",
    "11 s for this answer": "この答えに 11 秒",
    "no network, no server": "通信なし・サーバーなし",
    "two numbers.": "数字が 2 つ。", "0–1000 across": "画面を 0〜1000 と",
    "the screen,": "見たときの位置で、", "not pixels": "画素ではない",
    "from this run": "この実行の実物",
    "The model never sees a button. It sees pixels, and answers with a position.":
        "モデルはボタンを見ていません。画素を見て、位置で答えています。",
    "Two ways to find a button": "ボタンの見つけ方は 2 通り",
    "One needs the app's cooperation. One does not.":
        "片方は相手アプリの協力が要り、片方は要りません。",
    "the usual way": "ふつうのやり方", "this way": "このやり方",
    "needs the tree, the ids, and an app that exposes them":
        "ツリーと id、そしてそれを公開しているアプリが要る",
    "needs a screenshot. Nothing else.": "要るのはスクリーンショットだけ。",
    "So it drives apps that were never built for it — and pays with an inference per step.":
        "だから対応していないアプリも動かせます。代償は 1 ステップごとの推論です。",
    "The loop, and how it ends": "ループと、その終わり方",
    "capture": "撮る", "ask": "聞く", "press": "押す", "compare": "見比べる",
    "frame": "整形", "encode": "符号化", "decode": "生成", "act": "実行",
    "one screenshot": "スクショ 1 枚",
    "prompt → coordinates": "プロンプト → 座標",
    "before vs after": "押す前と押した後",
    "changed → go again": "変化した → もう一周",
    "identical → stop": "同一 → 停止",
    "why not just ask the model?": "モデルに聞けばいいのでは?",
    "asked on a screen where the goal was": "目標が達成済みの画面で聞いても、",
    "already met, it invented a target": "[] を返さず、それらしい対象を",
    "instead of returning []": "捏造してきます",
    "An agent is operating the phone": "エージェントが操作しています",
    # The goal string itself stays English in both cuts: it is what was typed
    # into the field on screen, so translating it would not match the phone.
    "THE INSTRUCTION TYPED": "入力した指示",
    "Three tasks, back to back. The waits for inference are cut here; "
    "the rest of the video keeps them.":
        "3 つのタスクを連続で。ここでは推論の待ち時間をカットしています。"
        "以降のクリップは実時間のままです。",
    "ON DEVICE": "実機",
    "An agent that operates an": "Android 端末を操作する",
    "Android phone, built on": "エージェントを、",
    "LFM2.5-VL": "LFM2.5-VL で。",
    "No view hierarchy, no selectors, no app cooperation.":
        "ビューツリーもセレクタも使わず、相手アプリの協力も要りません。",
    "LFM2.5-VL-3B int4 on a Pixel 8a. The app holds no INTERNET permission.":
        "Pixel 8a 上の LFM2.5-VL-3B int4。アプリは INTERNET 権限を持ちません。",
    "1 · One question,": "1 · 一問",
    "one answer": "一答",
    "You type what you want found": "探してほしいものを打つ",
    "The app steps back and takes one screenshot of what is behind it.":
        "アプリは裏に下がり、後ろの画面を 1 枚撮ります。",
    "A screenshot goes in, two numbers come out":
        "スクリーンショットを入れると、数字が 2 つ返る",
    "That is the whole mechanism.": "仕組みはこれだけです。",
    "the screenshot, and the point that came back":
        "送った画像と、返ってきた点",
    "the screenshot, then the text:": "画像、そのあとにこの文:",
    "from this run — coordinates, not a click":
        "この実行の実物 — クリックではなく座標",
    "The model never sees a button. It sees pixels":
        "モデルはボタンを見ていません。画素を見て、",
    "and answers with a position in [0, 1000].":
        "[0, 1000] の位置で答えているだけです。",
    "The coordinates become a press": "座標が押下になる",
    "No view hierarchy. No selectors.": "ビューツリーなし。セレクタなし。",
    "It reads the screen the way you do.": "人と同じように画面を見ています。",
    "what it does NOT use": "使っていないもの",
    "what it uses": "使っているもの",
    "the accessibility tree as a source of truth":
        "アクセシビリティツリー(情報源としては)",
    "view ids, XPath, or any selector": "view id・XPath・各種セレクタ",
    "cooperation from the app being driven": "操作される側のアプリの協力",
    "one screenshot per turn": "1 ターンにつきスクリーンショット 1 枚",
    "one vision-language model, on the phone": "端末上の視覚言語モデル 1 つ",
    "an accessibility service to *press* — never to read":
        "押すためのアクセシビリティサービス(読むためではない)",
    "So the same code drives an app that was never built for it,":
        "だから、そのために作られていないアプリも同じコードで動かせます。",
    "a screen with no automation hooks at all, or a game.":
        "自動化の口が一切ない画面でも、ゲームでも。",
    "The cost is that every step is an inference, and the answer":
        "代償は、毎ステップが推論であること、そして答えが",
    "is a guess about pixels rather than a lookup.":
        "参照ではなく画素に対する推測であることです。",
    "2 · A goal instead": "2 · 対象ではなく",
    "of a target": "目標を渡す",
    "Mode: Agent — the same question, asked once per screen.":
        "モード Agent — 同じ問いを、画面ごとに 1 回ずつ。",
    "A goal this time, not a target": "今度は対象ではなく目標",
    'It answers: "I\'ll work toward \"open the notification history\", a step at a time." Two screens deep, and nobody says which rows to press.':
        "返事は「open the notification history に向けて一歩ずつ進めます」。2 画面先で、どの行を押すかは誰も教えません。",
    'It answers: "I\'ll find \"Point to the Battery row.\" and press it." Then it steps back and takes one screenshot of what is behind it.':
        "返事は「Point to the Battery row. を見つけて押します」。そのあと裏に下がり、後ろの画面を 1 枚撮ります。",
    "A screenshot goes in, two numbers come out":
        "スクリーンショットを入れると、数字が 2 つ返る",
    "That is the whole mechanism.": "仕組みはこれだけです。",
    "the screenshot, and the point that came back":
        "送った画像と、返ってきた点",
    "the screenshot, then the text:": "画像、そのあとにこの文:",
    "from this run — coordinates, not a click":
        "この実行の実物 — クリックではなく座標",
    "The model never sees a button. It sees pixels":
        "モデルはボタンを見ていません。画素を見て、",
    "and answers with a position in [0, 1000].":
        "[0, 1000] の位置で答えているだけです。",
    "The coordinates become a press": "座標が押下になる",
    "No view hierarchy. No selectors.": "ビューツリーなし。セレクタなし。",
    "It reads the screen the way you do.": "人と同じように画面を見ています。",
    "what it does NOT use": "使っていないもの",
    "what it uses": "使っているもの",
    "the accessibility tree as a source of truth":
        "アクセシビリティツリー(情報源としては)",
    "view ids, XPath, or any selector": "view id・XPath・各種セレクタ",
    "cooperation from the app being driven": "操作される側のアプリの協力",
    "one screenshot per turn": "1 ターンにつきスクリーンショット 1 枚",
    "one vision-language model, on the phone": "端末上の視覚言語モデル 1 つ",
    "an accessibility service to *press* — never to read":
        "押すためのアクセシビリティサービス(読むためではない)",
    "So the same code drives an app that was never built for it,":
        "だから、そのために作られていないアプリも同じコードで動かせます。",
    "a screen with no automation hooks at all, or a game.":
        "自動化の口が一切ない画面でも、ゲームでも。",
    "The cost is that every step is an inference, and the answer":
        "代償は、毎ステップが推論であること、そして答えが",
    "is a guess about pixels rather than a lookup.":
        "参照ではなく画素に対する推測であることです。",
    "2 · A goal instead": "2 · 対象ではなく",
    "of a target": "目標を渡す",
    "Mode: Agent — the same question, asked once per screen.":
        "モード Agent — 同じ問いを、画面ごとに 1 回ずつ。",
    "A goal this time, not a target": "今度は対象ではなく目標",
    'It answers: "I\'ll work toward "open the notification history", a step at a time." Two screens deep, and nobody says which rows to press.':
        '返事は「open the notification history に向けて一歩ずつ進めます」。2 画面先で、どの行を押すかは誰も教えません。',
    'It answers: "I\'ll find "Point to the Battery row." and press it." Then it steps back and takes one screenshot of what is behind it.':
        '返事は「Point to the Battery row. を見つけて押します」。そのあと裏に下がり、後ろの画面を 1 枚撮ります。',
    "Knowing when to stop": "いつ止めるか",
    "The model will not tell you it has finished.":
        "モデルは「終わった」と言ってくれません。",
    "So the loop stops on evidence: it taps, takes another":
        "だからループは証拠で止めます。押して、もう一度撮って、",
    "screenshot, and compares the two.": "2 枚を見比べます。",
    "before": "押す前", "after": "押した後",
    "3 · What to do,": "3 · 何をするか、",
    "then where": "そのあとどこか",
    "Mode: Act — scroll, back and typing join the vocabulary.":
        "モード Act — スクロール・戻る・文字入力が語彙に加わります。",
    "Every turn:": "毎ターン:",
    "screenshot → prompt → coordinates → press":
        "スクショ → プロンプト → 座標 → 押下",
    "11–23 s per turn · 3B int4 · CPU only":
        "1 ターン 11〜23 秒 · 3B int4 · CPU のみ",
    "Three turns, and the third one moved nothing.":
        "3 ターン目は何も動かしませんでした。",
    "32 × 64 thumbnails, mean brightness difference.":
        "32 × 64 のサムネイルの平均輝度差。",
    "A phone that": "スマホが",
    "drives itself": "自分を操作する",
    "you type a goal · it looks at the screen · it presses":
        "目標を打つ → 画面を見る → 実際に押す",
    "LFM2.5-VL-3B int4 · Pixel 8a": "LFM2.5-VL-3B int4 · Pixel 8a",
    "The app holds no INTERNET permission.":
        "このアプリは INTERNET 権限を持っていません。",
    "Meet the agent": "これが",
    "that does it": "動かしている本体",
    "It waits at the edge of the screen while it thinks,":
        "考えている間は画面の端で待ち、",
    "then walks to the thing it is about to press.":
        "押す直前にその場所まで歩いていきます。",
    "1 · Ask for": "1 · ひとつだけ",
    "one thing": "頼む",
    "Mode: Tap — find it and press it once.":
        "モード Tap — 見つけて 1 回押す。",
    "2 · Give it": "2 · 目標を",
    "a goal": "渡す",
    "Mode: Agent — same app, and now it decides each tap.":
        "モード Agent — 同じアプリ。どこを押すかは自分で決める。",
    "3 · More than": "3 · タップ",
    "tapping": "以外も",
    "Mode: Act — it may scroll, go back, or type.":
        "モード Act — スクロール・戻る・文字入力もする。",
    "This run is logged: every prompt and reply below is from it.":
        "この実行はログを取ってあり、以下のプロンプトと返答はすべてその実物です。",
    "Every step:": "毎ステップ:",
    "look → decide → act": "見る → 決める → 動く",
    "11–23 s per step · 3B int4 · CPU only":
        "1 ステップ 11〜23 秒 · 3B int4 · CPU のみ",
    "No GPU or NPU path yet: this is the floor, not the ceiling.":
        "GPU も NPU も未着手。これは下限であって上限ではありません。",
    "Grounding, framing and the loop are a Kotlin library.":
        "座標取得・画像整形・ループは Kotlin ライブラリです。",

    # rail and chrome
    "HOW IT WORKS": "仕組み",
    "Task 1": "タスク 1", "Task 2": "タスク 2", "Task 3": "タスク 3",
    "Tap the row I name": "名前を言った行をタップする",
    "Get two screens deep": "2 つ先の画面まで進む",
    "Type into the search box": "検索欄に文字を入力する",
    "Mode: Tap": "モード Tap",
    "Mode: Agent — it picks each tap": "モード Agent — どこを押すかは自分で決める",
    "Mode: Act — scroll, back and typing": "モード Act — スクロール・戻る・入力",
    "Name the row you want pressed": "押してほしい行の名前を打つ",
    "It reads the name back, then steps behind what is on screen.":
        "名前を読み返してから、表示中の画面の裏に回ります。",
    "Settings → Notifications → Notification history, unaided.":
        "設定 → Notifications → Notification history を自力で。",
    "Say what to type, and where": "何をどこに打つかを言う",
    "Scrolling and pressing are its own business.":
        "スクロールと押下は本人に任せます。",
    "One way needs the app's ids. The other needs a screenshot.":
        "片方はアプリの id が要る。もう片方はスクショだけ。",
    "It stops when the screen stops changing.":
        "画面が変わらなくなったら止まる。",
    "The model does not remember the last screen.":
        "モデルは前の画面を覚えていない。",
    "This is what the app sends, word for word.":
        "アプリが送っている文面そのもの。",
    "A logged run: 34 s for the first answer.":
        "ログのある実行。最初の答えまで 34 秒。",
    "New screenshot, so a new answer.": "画面が変わったので答えも変わる。",
    "A new conversation per turn, closed after it.":
        "ターンごとに会話を作り、終わったら閉じます。",
    "What carries over": "引き継がれるもの",
    "a list the loop writes and pastes into the next prompt:":
        "ループが書いて次のプロンプトに貼る箇条書き:",
    "needs ids, and an app that exposes them": "id と、それを公開するアプリが要る",
    "needs a screenshot": "要るのはスクショだけ",
    "One inference per step is the price.": "代償は 1 ステップ 1 推論。",
    "the goal was already met, and it": "目標は達成済み。それでも [] を返さず",
    "invented a target instead of []": "対象を捏造してきました",
    "It works from a screenshot, on any app.":
        "スクショだけで、どのアプリでも動きます。",
    "3B int4 on a Pixel 8a. CPU only, no INTERNET permission.":
        "Pixel 8a 上の 3B int4。CPU のみ、INTERNET 権限なし。",
    "Mode: Tap — find it, press it once.": "モード Tap — 見つけて 1 回押す。",
    "Mode: Agent — the same question, once per screen.":
        "モード Agent — 同じ問いを画面ごとに 1 回。",
    "Every prompt and reply below is from this run's log.":
        "以下のプロンプトと返答は、この実行のログの実物です。",
    "It reads it back, then steps behind what is on screen.":
        "読み返してから、表示中の画面の裏に回ります。",
    "It stops: the screen did not change": "停止: 画面が変わらなかった",
    "Three turns; the third moved nothing.": "3 ターン目は何も動かしませんでした。",
    "The coordinates become a press": "座標が押下になる",
    'typed "wifi" into the search box': '検索欄に "wifi" を入力した',
    '2 · tapped Notification history': '2 · Notification history を押した',
    'the model answered {"action": "done"}': 'モデルが {"action": "done"} と答えた',
    "SENT TOGETHER": "まとめて送る", "MODEL": "モデル", "ANSWER": "返答",
    "PRESS": "押す", "on the phone, 11 s": "端末上で 11 秒",
    "0–1000,": "0〜1000 の位置。", "not pixels": "画素ではない",
    "It never sees a button. It sees pixels, and answers with a position.":
        "ボタンは見ていません。画素を見て、位置で答えています。",
    "A screenshot goes in. Coordinates come out.":
        "スクリーンショットを入れると、座標が返る。",
    "ON THE PHONE — REAL TIME": "実機・等倍",
    "THE WHOLE INTERFACE": "操作画面はこれだけ",
    "WHAT IT SAYS BACK": "返ってくる言葉",
    "the whole screen": "画面全体",
    "type a goal, press Run": "目標を打って Run",

    # instruction shots
    "You type the goal and press Run": "人が目標を打って Run を押す",
    "You type the goal — the agent answers before you press Run":
        "目標を打つと、Run を押す前にエージェントが返事をする",
    "Same box, and the answer changes with the mode":
        "同じ入力欄。モードによって返事が変わる",
    "Then the app hides itself and looks at the screen behind it.":
        "アプリは自分を裏に隠し、後ろにある画面を見ます。",
    "Same box. A goal this time, not a target": "同じ入力欄。今度は対象ではなく目標",
    "Two screens deep. Nobody says which rows to press.":
        "2 画面先。どの行を押すかは誰も教えません。",
    "Same box again, third mode": "また同じ入力欄、3 つ目のモード",
    "The five modes are the only controls this app has.":
        "このアプリの操作系は 5 つのモードだけです。",

    # device captions
    "It walks to the key and presses it": "キーまで歩いて押す",
    "The badge is the agent; the press is a real gesture.":
        "このバッジがエージェント本体。押下は本物のジェスチャです。",
    "It points at the Battery row, and taps it": "Battery の行を指して、押す",
    "Settings opens Battery.": "設定が Battery を開きます。",
    "1 · tapped Notifications": "1 · Notifications を押した",
    "Settings → Notifications": "設定 → Notifications",
    "2 · tapped Notification history — goal reached":
        "2 · Notification history を押した — 目標到達",
    "Notifications → Notification history": "Notifications → Notification history",
    "Loop stops: the screen did not change": "ループ停止: 画面が変化しなかった",
    "Three steps, and the third one moved nothing.":
        "3 歩目は何も動かしませんでした。",
    '1 · typed "wifi" into the search box': '1 · 検索欄に "wifi" を入力した',
    "The search screen opened and the text landed.":
        "検索画面が開き、文字が入りました。",
    '2 · the model answered {"action": "done"}':
        '2 · モデルが {"action": "done"} と答えた',
    "Two steps, three model calls, 2 min 10 s.":
        "2 ステップ・推論 3 回・2 分 10 秒。",

    # beat titles and prose
    "One turn, start to finish": "1 ターンの全体",
    "The same three moves repeat for every step.":
        "毎ステップ、この 3 つの繰り返しです。",
    "WHAT THE MODEL IS SENT": "モデルに送るもの",
    "WHAT COMES BACK": "返ってくるもの",
    "WHAT IS DONE WITH IT": "それをどう使うか",
    "the image part goes first — text first breaks it":
        "画像パートが先。テキストを先にすると壊れます",
    "illustrative values — one JSON object per match":
        "値は例示。一致ごとに JSON オブジェクトが 1 つ",
    "Then the screen has changed, and the next turn":
        "画面が変わったら、次のターンは",
    "starts over with a fresh screenshot.":
        "新しいスクリーンショットから始めます。",
    "Every turn starts from nothing": "毎ターン、ゼロから始まる",
    "The model is not remembering the last screen.":
        "モデルは前の画面を覚えていません。",
    "A new conversation is opened for each turn and":
        "ターンごとに会話を作り直して",
    "closed after it. No history, no carried cache.":
        "閉じます。履歴もキャッシュも持ち越しません。",
    "So what carries over?": "では何が引き継がれるのか",
    "A list the loop writes in plain sentences and":
        "ループが平文で書いた箇条書きを",
    "pastes into the next prompt:": "次のプロンプトに貼ります:",
    "Turn 2 — same question, new screen": "ターン 2 — 同じ問い、新しい画面",
    "Nothing about the prompt changed.": "プロンプトは何も変えていません。",
    "The screen behind it opens Notification history,":
        "後ろの画面が Notification history を開き、",
    "and that is the goal reached.": "それが目標達成です。",
    "The loop does not know that yet.": "ループはまだそれを知りません。",
    "It will ask once more.": "もう一度だけ聞きます。",
    "Turn 3 — it answers anyway": "ターン 3 — それでも答えてしまう",
    "This is the behaviour the loop is built around.":
        "ループはこの挙動を前提に組んであります。",
    "Asked to point at a screen where the goal is":
        "目標が達成済みの画面で指せと言われても、",
    "already met, it invents a target anyway.":
        "それらしい対象を捏造します。",
    "from this run — the goal was already met":
        "この実行の実物 — 目標は達成済みでした",
    "It was told it could return [] and it did not.":
        "[] を返してよいと明示しても返しません。",
    "So the loop stops on evidence instead: it taps,":
        "だからループは証拠で止めます。押して、",
    "takes another screenshot, and compares.":
        "もう一度撮って、見比べます。",
    "before the tap": "押す前", "after the tap": "押した後",
    "identical": "同一", "→ stop": "→ 停止",
    "32 × 64 thumbnails, mean brightness difference.":
        "32 × 64 のサムネイルの平均輝度差。",
    "A tap that changes nothing ends the run.":
        "何も変えないタップで実行を終えます。",
    "The prompt, in full": "プロンプト全文",
    "Read out of the source, not retyped.":
        "ソースから読み出したもので、書き写しではありません。",
    "PLAN PROMPT — VERBATIM": "PLAN プロンプト(実際は英語・以下は訳)",
    "Read out of the source, not retyped.":
        "ソースから読み出した原文の訳です。実際に送るのは英語のままです。",
    "The screenshot goes in front of all of this.":
        "この全文の前にスクリーンショットが入ります。",
    "What the next turn is told": "次のターンに渡すもの",
    "The loop writes the memory, not the model.":
        "記憶を書くのはループで、モデルではありません。",
    "Past tense, one line each.": "過去形で 1 行ずつ。",
    "A JSON transcript makes the model echo the":
        "JSON の履歴にすると、モデルは答えずに",
    "transcript format back instead of answering.":
        "その形式を真似て返してきます。",
    "So the whole memory of the run is a handful":
        "つまり実行全体の記憶は数行の文で、",
    "of sentences, rewritten into every prompt.":
        "毎回プロンプトに書き直されます。",
    "The turn that types": "文字を入力するターン",
    "One action carries both the field and the text.":
        "1 つの行動に、対象の欄と文字列の両方が載ります。",
    "from this run": "この実行の実物",
    '"wifi" came from the goal, not from the': '"wifi" は目標から取られています。',
    "examples in the prompt — which took a line":
        "プロンプトの例文からではありません。ここは",
    "of prompt to fix.": "1 行足して直しました。",
    "Then the loop, not the model:": "ここからはモデルではなくループの仕事:",
    "is a field already focused?": "すでにフォーカスされた欄があるか?",
    "no  → ground the target, tap it": "無 → 対象を座標化して押す",
    "yes → leave it alone, a tap would lose it":
        "有 → 触らない。押すとフォーカスが外れる",
    "then set the text": "そのうえで文字を入れる",
    "Step 1 — what went in, what came back": "ステップ 1 — 入れたものと返ったもの",
    "A real run, logged. 34 s for the first answer.":
        "実行ログそのもの。最初の答えまで 34 秒。",
    "STEP 1 OF 2": "ステップ 1 / 2", "STEP 2 OF 2": "ステップ 2 / 2",
    "PLAN — our prompt": "PLAN — 自前のプロンプト",
    "PLAN — our prompt, rewritten": "PLAN — 書き直した自前のプロンプト",
    "GROUND — the vendor prompt, verbatim":
        "GROUND — ベンダーのプロンプト原文",
    "sent with the screenshot on the left": "左のスクリーンショットと一緒に送信",
    "same screenshot, second question": "同じ画像で 2 問目",
    "the loop focuses the field, then types": "ループが欄を選んでから入力します",
    "the only memory that carries over": "引き継がれる唯一の記憶",
    "no grounding call: nothing to locate": "座標が不要なので GROUND は呼ばれません",
    "Step 2 — a new screenshot, one question":
        "ステップ 2 — 新しい画像、問いは 1 つ",
    "The screen changed, so the answer changes.":
        "画面が変わったので答えも変わります。",
    "Three model calls in all, for two steps.":
        "2 ステップで、推論は合計 3 回。",
    "Two of them needed a coordinate; one did not.":
        "座標が要ったのは 2 回、要らなかったのが 1 回。",
    "what the model was sent": "モデルに送った画像",
    "screenshot A": "スクリーンショット A", "screenshot B": "スクリーンショット B",
    "screenshot C": "スクリーンショット C",
    "coordinates for screen A": "画面 A に対する座標",
    "coordinates for screen B": "画面 B に対する座標",
    "coordinates for screen C": "画面 C に対する座標",
    '"Point to the Battery row."': '「Battery の行を指してください。」',
    "with the text below": "右のテキストと一緒に",
}


def _waited_ja(d, elapsed, real_total, shown_over):
    """The wait line is built from numbers, so it needs its own translation."""
    factor = real_total / shown_over if shown_over else 1
    W, H = demo_chrome.W, demo_chrome.H
    y = H - 110
    d.rectangle([0, y - 30, W, H], fill=(8, 10, 13))
    d.text((60, y - 14), f"{elapsed:0.1f} 秒",
           font=demo_chrome.font(JA_BOLD, 46), fill=demo_chrome.GREEN)
    d.text((250, y - 4),
           f"端末はまだ計算中 — 全体で {real_total:0.0f} 秒、×{factor:0.0f} で再生",
           font=demo_chrome.font(JA_REG, 30), fill=demo_chrome.DIM)
    width = int((W - 120) * min(1.0, elapsed / real_total if real_total else 0))
    d.rounded_rectangle([60, H - 42, W - 60, H - 32], radius=5, fill=(30, 34, 40))
    if width > 12:
        d.rounded_rectangle([60, H - 42, 60 + width, H - 32], radius=5,
                            fill=demo_chrome.GREEN)


JA_PROMPTS = {
    "planner": """あなたは Android 端末の画面を見て操作しています。

目標: search settings for wifi

ここまでにやったこと:
まだ何もしていません。

画面を見て、次にとる行動をひとつ選んでください。JSON オブジェクトを
ひとつだけ返し、それ以外は何も書かないでください。以下は 5 種類の
行動の例で、値は作り物です。この画面に合わせて自分の言葉で書いて
ください:

{"action": "tap", "target": "the Notifications row"}
{"action": "scroll", "direction": "down"}
{"action": "back"}
{"action": "type", "target": "the search box", "text": "battery"}
{"action": "done"}

必要なものが表示領域より下にありそうなときは "scroll"。この画面が
行き止まりなら "back"。目標が達成済みだと画面から分かるときだけ
"done" を使ってください。

"type" では対象の欄を "target" に、入力する文字を "text" に書きます。
どちらも必須で、"text" は上の目標から取ってください。例文から取っては
いけません。欄のフォーカスはこちらで合わせるので、そのために 1 手
使わないでください。""",
    "vendor": """物や領域に対応する点を求められたときは、妥当な JSON 配列を返してください。
配列の各要素は次を持つオブジェクトです:
- image_id: 画像の 0 始まりの番号
- point_2d: [x, y]。[0, 1000] に正規化した整数座標
- label: その物や領域に対してあなたが付ける簡潔なラベル

見えている一致ごとに 1 要素返してください。ひとつも見えなければ [] を返してください。""",
    "taploop": """目標: open the notification history
これが現在の画面です。目標に近づくために次に押すべき要素をひとつだけ
指してください。目標が達成済みの場合、またはこの画面に役立つものが
何もない場合は [] を返してください。""",
}


def apply():
    """Swap the fonts and translate known strings, once, for the whole build."""
    demo_chrome.BOLD = JA_BOLD
    demo_chrome.REG = JA_REG
    demo_chrome.MONO = JA_MONO

    # Width has to be measured on the string that will actually be drawn, or a
    # Japanese line gets a font size chosen for its English original and runs
    # off the card.
    original_fitted = demo_chrome.fitted

    def fitted_ja(d, text, path, size, max_width):
        return original_fitted(d, TEXT.get(text, TEXT.get(text.strip(), text)),
                               path, size, max_width)

    demo_chrome.fitted = fitted_ja

    # Captions are wrapped into lines before they are drawn, so the lookup has
    # to happen here too — otherwise `d.text` only ever sees fragments and no
    # caption is ever translated.
    original_wrap_chrome = demo_chrome.wrap

    # Japanese may break between any two characters, but a Latin word may not:
    # a caption naming "Notification history" was breaking after the "N". So a
    # run of Latin/digits is one unbreakable chunk, and everything else is a
    # chunk of its own. Closing punctuation is glued to the chunk before it so
    # a line never opens with 。 or 」.
    def _chunks(text):
        out, run = [], ""
        for ch in text:
            latin = ch.isascii() and (ch.isalnum() or ch in "'-_./:")
            if latin:
                run += ch
                continue
            if run:
                out.append(run)
                run = ""
            if ch in "。、，．）」』】〉！？!?,.:;" and out:
                out[-1] += ch
            else:
                out.append(ch)
        if run:
            out.append(run)
        return out

    def wrap_ja(d, text, f, max_width):
        text = TEXT.get(text, TEXT.get(text.strip(), text))
        if not any(ord(ch) > 0x2E80 for ch in text):
            return original_wrap_chrome(d, text, f, max_width)
        out, line = [], ""
        for chunk in _chunks(text):
            probe = line + chunk
            if d.textlength(probe, font=f) > max_width and line:
                out.append(line.rstrip())
                line = chunk.lstrip()
            else:
                line = probe
        if line:
            out.append(line.rstrip())
        return out

    demo_chrome.wrap = wrap_ja
    import demo_beats
    demo_beats.fitted = fitted_ja

    # the prompts themselves, so a reviewer can read what is being sent
    import demo_prompts
    demo_prompts.planner_prompt = lambda goal, done: JA_PROMPTS["planner"]
    demo_prompts.vendor_system_prompt = lambda: JA_PROMPTS["vendor"]
    demo_prompts.tap_loop_prompt = lambda goal: JA_PROMPTS["taploop"]

    # Japanese glyphs are twice as wide, so a column measured in characters has
    # to be halved or every wrapped prompt line runs off the card.
    original_wrap = demo_prompts.wrapped

    def wrapped_ja(text, width):
        """Japanese does not break on spaces, so wrap by character count.

        The Latin wrapper splits on spaces and a Japanese sentence has almost
        none, so it returned one very long line that ran off every card.
        """
        if not any(ord(ch) > 0x2E80 for ch in text):
            return original_wrap(text, width)
        limit = max(8, width // 2)
        out = []
        for para in text.split("\n"):
            if not para:
                out.append("")
                continue
            while len(para) > limit:
                out.append(para[:limit])
                para = para[limit:]
            out.append(para)
        return out

    demo_prompts.wrapped = wrapped_ja

    demo_chrome.waited = _waited_ja
    import demo_beats
    demo_beats.waited = _waited_ja

    original = ImageDraw.ImageDraw.text

    def translated(self, xy, text, *args, **kwargs):
        if isinstance(text, str):
            text = TEXT.get(text, TEXT.get(text.strip(), text))
        return original(self, xy, text, *args, **kwargs)

    ImageDraw.ImageDraw.text = translated
