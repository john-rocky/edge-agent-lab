package io.github.johnrocky.phoneagent

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.SystemClock
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.ComponentActivity
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.ThinkingConfig
import java.io.File
import java.util.concurrent.Executors

/**
 * One screen: a request goes in, the model thinks (streamed), calls phone tools (executed for real),
 * reads their results, and answers. Everything runs on the phone from a local .litertlm.
 *
 * Launch extras (all optional):
 *   --es model /path/to/model.litertlm   default: <external files dir>/model.litertlm
 *   --es backend cpu|gpu                  default: cpu
 *   --es prompt "..."                     pre-filled request
 *   --es name "Spark-X2.5-1.7B int4"      label shown in the header
 *   --es fixture seed|wipe                seed: two events on the agent's own calendar for tomorrow; wipe: delete that calendar
 *   --ez autorun true                     press Run by itself once the model is loaded
 *   --ei threads 4                        CPU backend thread count (default 4; the runtime's own default ran on one core)
 *   --ez cache true                       give the engine a cache dir (XNNPACK weight cache); default off
 *   --ez notools true                     plain chat, no tool list in the prompt (timing control)
 */
class MainActivity : ComponentActivity() {
    private val bg = Executors.newSingleThreadExecutor()
    private val tools = PhoneTools(this)
    private var engine: Engine? = null
    private var conv: Conversation? = null

    private lateinit var timeline: LinearLayout
    private lateinit var scroll: ScrollView
    private lateinit var input: EditText
    private lateinit var send: Button
    private lateinit var status: TextView
    private lateinit var subtitle: TextView

    private var modelPath = ""
    private var backendName = "cpu"
    private var modelName = "Spark-X2.5-1.7B int4"
    private var turns = 0
    private var toolCalls = 0
    private var runStart = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Show over the lock screen and light the display: a locked phone parks a hidden activity's process in the
        // background cpuset (little cores, throttled), which made the same model run ~10x slower than the CLI.
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_main)
        timeline = findViewById(R.id.timeline); scroll = findViewById(R.id.scroll)
        input = findViewById(R.id.input); send = findViewById(R.id.send)
        status = findViewById(R.id.status); subtitle = findViewById(R.id.subtitle)

        modelPath = intent.getStringExtra("model") ?: File(getExternalFilesDir(null), "model.litertlm").absolutePath
        backendName = intent.getStringExtra("backend") ?: "cpu"
        intent.getStringExtra("name")?.let { modelName = it }
        input.setText(intent.getStringExtra("prompt") ?: DEFAULT_PROMPT)
        subtitle.text = "$modelName · ${backendName.uppercase()} · on-device, no network"
        send.isEnabled = false
        send.setOnClickListener { startRun() }

        val perms = arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
        if (perms.any { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }) requestPermissions(perms, 1)
        when (intent.getStringExtra("fixture")) {
            "seed" -> status.text = tools.seedTomorrow()
            "wipe" -> status.text = tools.wipeOwnCalendar()
        }

        bg.execute { loadModel() }
    }

    private fun loadModel() {
        ui { status.text = "Loading model…" }
        val t0 = SystemClock.elapsedRealtime()
        try {
            val be: Backend = if (backendName == "gpu") Backend.GPU() else Backend.CPU(threadCount = intent.getIntExtra("threads", 4))
            val cache = if (intent.getBooleanExtra("cache", false)) cacheDir.absolutePath else null
            val e = Engine(EngineConfig(modelPath = modelPath, backend = be, maxNumTokens = 4096, cacheDir = cache))
            e.initialize()
            engine = e
            conv = newConversation(e)
            val secs = (SystemClock.elapsedRealtime() - t0) / 1000.0
            Log.i(TAG, "loaded $modelPath on $backendName in $secs s")
            ui {
                status.text = "Ready · loaded in %.1f s".format(secs); send.isEnabled = true
                if (intent.getBooleanExtra("autorun", false)) send.postDelayed({ startRun() }, 1500)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "load failed", t)
            ui { status.text = "Load failed: ${t.message}"; addCard("Error", t.toString(), C_BAD) }
        }
    }

    /** The date goes in as system text (the Mac sweeps that passed ran this way); the tools stay the way to act. */
    private fun systemText(): String = "The current date and time is " +
        java.text.SimpleDateFormat("EEEE, yyyy-MM-dd HH:mm", java.util.Locale.US).format(java.util.Date()) +
        ". You control the user's phone through the tools; use them."

    private fun newConversation(e: Engine): Conversation = e.createConversation(
        ConversationConfig(
            systemInstruction = Contents.of(systemText()),
            samplerConfig = SamplerConfig(topK = 1, topP = 1.0, temperature = 0.0, seed = 0),
            thinkingConfig = ThinkingConfig(true),
            automaticToolCalling = false,
            // The bundle's chat template renders `tools` the vendor way (## Tools ... <tools>JSON</tools>);
            // the app parses the calls, so the runtime's own tool machinery stays out of the loop.
            extraContext = if (intent.getBooleanExtra("notools", false)) emptyMap() else mapOf("tools" to tools.descriptions()),
        ),
    )

    private fun startRun() {
        val text = input.text.toString().trim()
        if (text.isEmpty() || conv == null) return
        send.isEnabled = false; input.isEnabled = false; input.text.clear()
        turns = 0; toolCalls = 0; runStart = SystemClock.elapsedRealtime()
        addBubble(text)
        turn(Message.user(text))
    }

    /** One model turn: stream thought + text, then either run the tool calls and go again, or finish. */
    private fun turn(msg: Message) {
        val c = conv ?: return
        turns++
        val t0 = SystemClock.elapsedRealtime()
        val thoughtCard = ThoughtCard(turns)
        val thought = StringBuilder()
        val text = StringBuilder()
        status.text = "Thinking… (turn $turns)"
        c.sendMessageAsync(msg, object : MessageCallback {
            override fun onMessage(message: Message) {
                val t = message.contents.contents.filterIsInstance<Content.Text>().joinToString("") { it.text }
                val th = message.channels["thought"] ?: ""
                if (t.isEmpty() && th.isEmpty()) return
                ui {
                    if (th.isNotEmpty()) { thought.append(th); thoughtCard.update(thought) }
                    if (t.isNotEmpty()) { text.append(t); thoughtCard.preview(text) }
                }
            }
            override fun onDone() {
                val secs = (SystemClock.elapsedRealtime() - t0) / 1000.0
                Log.i(TAG, "turn $turns done in $secs s, thought ${thought.length} chars, text: $text")
                ui { thoughtCard.done(thought.length, secs); afterTurn(text.toString()) }
            }
            override fun onError(e: Throwable) {
                Log.e(TAG, "turn $turns failed", e)
                ui { addCard("Error", e.toString(), C_BAD); finish(false) }
            }
        })
    }

    private fun afterTurn(text: String) {
        val calls = SparkToolCalls.parse(text)
        val said = SparkToolCalls.withoutCalls(text)
        if (calls.isEmpty()) {
            addCard("Answer", if (said.isEmpty()) "(no text)" else said, C_ANSWER, big = true).body.text = md(said)
            finish(true)
            return
        }
        if (said.isNotEmpty()) addCard("Agent", said, C_CARD).body.text = md(said)
        if (turns >= MAX_TURNS) { addCard("Stopped", "Turn limit reached", C_BAD); finish(false); return }
        val responses = ArrayList<Content>()
        for (call in calls) {
            toolCalls++
            val card = addCard("${tools.icon(call.name)} ${SparkToolCalls.render(call)}", "running…", C_TOOL, mono = true)
            val result = tools.call(call.name, call.args)
            Log.i(TAG, "tool ${SparkToolCalls.render(call)} -> $result")
            card.body.text = (if (result.startsWith("Error")) "✗ " else "✓ ") + result
            card.body.setTextColor(if (result.startsWith("Error")) Color.parseColor("#F85149") else Color.parseColor("#3FB950"))
            responses.add(Content.ToolResponse(call.name, result))
        }
        turn(Message.tool(Contents.of(responses)))
    }

    private fun finish(ok: Boolean) {
        val total = (SystemClock.elapsedRealtime() - runStart) / 1000.0
        status.text = if (ok) "Done · $turns turns · $toolCalls tool calls · %.0f s".format(total) else "Stopped"
        Log.i(TAG, "run finished ok=$ok turns=$turns toolCalls=$toolCalls total=$total s")
        if (ok) addCard("Phone state now", tools.phoneState(), C_STATE, mono = true)
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER; setPadding(0, dp(8), 0, dp(8)) }
        row.addView(chip("Open Clock") { startActivity(tools.showAlarms()) })
        row.addView(chip("Open Calendar") { startActivity(tools.showCalendar(PhoneTools.tomorrowNoon())) })
        timeline.addView(row)
        scrollDown()
        // The runtime's own rule: a finished conversation is not reused. Open a fresh one for the next request.
        bg.execute {
            try { conv?.close() } catch (_: Throwable) {}
            conv = engine?.let { newConversation(it) }
            ui { send.isEnabled = true; input.isEnabled = true }
        }
    }

    // ---- UI pieces ----------------------------------------------------------------------------

    private inner class Card(val root: LinearLayout, val title: TextView, val body: TextView)

    private fun addCard(title: String, bodyText: String, color: Int, mono: Boolean = false, big: Boolean = false): Card {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(color)
            setPadding(dp(14), dp(10), dp(14), dp(12))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(10) }
        }
        val t = TextView(this).apply {
            text = title; setTextColor(Color.parseColor("#9DA7B3")); setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = if (mono) Typeface.MONOSPACE else Typeface.DEFAULT_BOLD
        }
        val b = TextView(this).apply {
            text = bodyText; setTextColor(Color.parseColor("#E6EDF3")); setTextSize(TypedValue.COMPLEX_UNIT_SP, if (big) 17f else 15f)
            setPadding(0, dp(4), 0, 0)
            if (mono) typeface = Typeface.MONOSPACE
        }
        root.addView(t); root.addView(b)
        timeline.addView(root); scrollDown()
        return Card(root, t, b)
    }

    private fun addBubble(text: String) {
        val v = TextView(this).apply {
            this.text = text; setTextColor(Color.WHITE); setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            background = rounded(C_USER); setPadding(dp(14), dp(10), dp(14), dp(10))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.END; bottomMargin = dp(12); leftMargin = dp(40)
            }
        }
        timeline.addView(v); scrollDown()
    }

    /** The streamed reasoning: a fixed-height window that follows the tail, then a summary line when the turn ends. */
    private inner class ThoughtCard(private val turn: Int) {
        private val card = addCard("Thinking · turn $turn", "", C_THOUGHT)
        private val window = ScrollView(this@MainActivity).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(150))
            isVerticalScrollBarEnabled = false
        }
        private val textView = TextView(this@MainActivity).apply {
            setTextColor(Color.parseColor("#8B949E")); setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            typeface = Typeface.create("sans-serif-light", Typeface.ITALIC)
            setPadding(0, dp(6), 0, dp(2))
        }
        init {
            card.root.removeView(card.body)
            window.addView(textView); card.root.addView(window)
        }
        fun update(s: CharSequence) { textView.text = s; window.post { window.fullScroll(View.FOCUS_DOWN) } }
        fun preview(s: CharSequence) { card.title.text = "Thinking · turn $turn · writing" }
        fun done(chars: Int, secs: Double) {
            card.title.text = "Thought · %d characters · %.1f s".format(chars, secs)
            window.layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                if (chars < 220) ViewGroup.LayoutParams.WRAP_CONTENT else dp(96))
            window.post { window.fullScroll(View.FOCUS_DOWN) }
        }
    }

    private fun chip(label: String, onClick: () -> Unit): Button = Button(this).apply {
        text = label; isAllCaps = false; setTextColor(Color.WHITE); background = rounded(C_USER)
        setPadding(dp(16), dp(6), dp(16), dp(6))
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { marginEnd = dp(8) }
        setOnClickListener { onClick() }
    }

    /** Markdown-lite for the model's replies: **bold**, "### " headings, "- " bullets, "---" rules. */
    private fun md(src: String): CharSequence {
        val out = SpannableStringBuilder()
        for (raw in src.trim().lines()) {
            var line = raw.trimEnd()
            if (line.trim() == "---") continue
            // Markdown tables: drop the |---| rule, turn a row into "cell · cell · cell".
            if (line.trimStart().startsWith("|")) {
                val cells = line.trim().trim('|').split("|").map { it.trim() }
                if (cells.all { it.matches(Regex("^:?-{2,}:?$")) }) continue
                line = cells.filter { it.isNotEmpty() }.joinToString("  ·  ")
            }
            var heading = false
            if (line.startsWith("### ") || line.startsWith("## ") || line.startsWith("# ")) { line = line.substringAfter(" "); heading = true }
            if (line.trimStart().startsWith("- ")) line = line.replaceFirst("- ", "•  ")
            val start = out.length
            var i = 0
            while (i < line.length) {
                val b = line.indexOf("**", i)
                if (b < 0) { out.append(line.substring(i)); break }
                val e = line.indexOf("**", b + 2)
                if (e < 0) { out.append(line.substring(i)); break }
                out.append(line.substring(i, b))
                val bs = out.length
                out.append(line.substring(b + 2, e))
                out.setSpan(StyleSpan(Typeface.BOLD), bs, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                i = e + 2
            }
            if (heading) out.setSpan(StyleSpan(Typeface.BOLD), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            out.append("\n")
        }
        while (out.isNotEmpty() && out.last() == '\n') out.delete(out.length - 1, out.length)
        return out
    }

    private fun rounded(color: Int) = GradientDrawable().apply { cornerRadius = dp(14).toFloat(); setColor(color) }
    private fun dp(v: Int): Int = (v * resources.displayMetrics.density + 0.5f).toInt()
    private fun scrollDown() = scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    private fun ui(f: () -> Unit) = runOnUiThread(f)

    override fun onDestroy() {
        super.onDestroy()
        bg.execute { try { conv?.close() } catch (_: Throwable) {}; try { engine?.close() } catch (_: Throwable) {} }
    }

    companion object {
        const val TAG = "PhoneAgent"
        const val MAX_TURNS = 8
        val C_CARD = Color.parseColor("#161B22")
        val C_THOUGHT = Color.parseColor("#12171E")
        val C_TOOL = Color.parseColor("#1B2430")
        val C_ANSWER = Color.parseColor("#1F2A1F")
        val C_USER = Color.parseColor("#2F6FDB")
        val C_BAD = Color.parseColor("#3A1D1D")
        val C_STATE = Color.parseColor("#1C2333")
        const val DEFAULT_PROMPT = "My flight lands at 6:40 tomorrow morning and I have to be at the office by 9:00. The trip from the airport takes about an hour. Set an alarm so I am up in time, put the commute on my calendar, and check that it does not clash with anything I already have tomorrow."
    }
}
