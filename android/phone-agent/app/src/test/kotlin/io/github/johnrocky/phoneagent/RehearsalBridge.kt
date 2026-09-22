package io.github.johnrocky.phoneagent

import com.google.gson.Gson

/** Host rehearsal uses the exact app parser/system text without launching Android. */
fun main(args: Array<String>) {
    if (args.firstOrNull() == "system") {
        print(PhoneAgentFormat.QWENXML.systemText(args[1]))
        return
    }
    val text = System.`in`.bufferedReader().readText()
    print(Gson().toJson(mapOf(
        "calls" to QwenXmlToolCalls.parse(text),
        "said" to QwenXmlToolCalls.withoutCalls(text),
        "malformed" to QwenXmlToolCalls.hasUnparsedMarkup(text),
    )))
}
