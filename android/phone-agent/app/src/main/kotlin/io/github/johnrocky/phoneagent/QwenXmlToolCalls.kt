package io.github.johnrocky.phoneagent

/** Native Qwen XML is text, not a runtime ToolCall event. Never execute an incomplete block. */
object QwenXmlToolCalls {
    data class Call(val name: String, val args: Map<String, String>, val raw: String)
    private data class Match(val call: Call, val start: Int, val end: Int)
    private const val OPEN = "<tool_call>"
    private const val CLOSE = "</tool_call>"

    fun parse(text: String): List<Call> = matches(text).map { it.call }

    /** Only remove valid calls; malformed output remains visible and is never presented as success. */
    fun withoutCalls(text: String): String {
        val out = StringBuilder()
        var cursor = 0
        for (match in matches(text)) {
            out.append(text.substring(cursor, match.start))
            cursor = match.end
        }
        return out.append(text.substring(cursor)).toString().trim()
    }

    fun hasUnparsedMarkup(text: String): Boolean {
        val rest = withoutCalls(text)
        return listOf("<tool_call", "</tool_call", "<function=", "</function", "<parameter=", "</parameter")
            .any { rest.contains(it) }
    }

    private fun matches(text: String): List<Match> {
        val out = mutableListOf<Match>()
        var cursor = 0
        while (true) {
            val start = text.indexOf(OPEN, cursor)
            if (start < 0) break
            val close = text.indexOf(CLOSE, start + OPEN.length)
            if (close < 0) break
            val nested = text.indexOf(OPEN, start + OPEN.length)
            if (nested in (start + OPEN.length) until close) {
                // Recover the next complete block, but leave the broken prefix visible.
                cursor = nested
                continue
            }
            val end = close + CLOSE.length
            parseBody(text.substring(start + OPEN.length, close), text.substring(start, end))?.let {
                out.add(Match(it, start, end))
            }
            cursor = end
        }
        return out
    }

    // A small hand scanner avoids Android ICU/JVM regex differences and XML entity/DTD expansion.
    private fun parseBody(source: String, raw: String): Call? {
        val body = source.trim()
        if (!body.startsWith("<function=")) return null
        val nameEnd = body.indexOf('>')
        if (nameEnd < 0) return null
        val name = body.substring("<function=".length, nameEnd)
        if (!identifier(name)) return null
        val args = linkedMapOf<String, String>()
        var cursor = nameEnd + 1
        while (true) {
            while (cursor < body.length && body[cursor].isWhitespace()) cursor++
            if (body.startsWith("</function>", cursor)) {
                if (body.substring(cursor + "</function>".length).isNotBlank()) return null
                return Call(name, args, raw)
            }
            if (!body.startsWith("<parameter=", cursor)) return null
            val keyEnd = body.indexOf('>', cursor)
            if (keyEnd < 0) return null
            val key = body.substring(cursor + "<parameter=".length, keyEnd)
            if (!identifier(key) || args.containsKey(key)) return null
            val valueEnd = body.indexOf("</parameter>", keyEnd + 1)
            if (valueEnd < 0) return null
            val value = body.substring(keyEnd + 1, valueEnd).trim()
            if (listOf("<parameter=", "<function=", "</function>", OPEN, CLOSE).any { value.contains(it) }) return null
            args[key] = value
            cursor = valueEnd + "</parameter>".length
        }
    }

    private fun identifier(s: String): Boolean = s.isNotEmpty() &&
        (s[0] in 'A'..'Z' || s[0] in 'a'..'z' || s[0] == '_') &&
        s.all { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it in "_.-" }
}
