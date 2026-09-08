package io.github.johnrocky.phoneagent

import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive

/**
 * Spark-X2.5 writes tool calls in its own form:
 *   <tool_call>NAME<arg_key>K</arg_key><arg_value>V</arg_value>...</tool_call>
 * The LiteRT-LM runtime does not parse that form (it knows the Gemma and JSON ones), so the app does.
 */
object SparkToolCalls {
    data class Call(val name: String, val args: Map<String, Any?>, val raw: String)

    private val CALL = Regex("<tool_call>(.*?)</tool_call>", RegexOption.DOT_MATCHES_ALL)
    private val NAME = Regex("^\\s*([A-Za-z_][A-Za-z0-9_]*)")
    private val ARG = Regex("<arg_key>(.*?)</arg_key>\\s*<arg_value>(.*?)</arg_value>", RegexOption.DOT_MATCHES_ALL)

    fun parse(text: String): List<Call> = CALL.findAll(text).mapNotNull { m ->
        val body = m.groupValues[1]
        val n = NAME.find(body) ?: return@mapNotNull null
        val args = LinkedHashMap<String, Any?>()
        for (a in ARG.findAll(body.substring(n.range.last + 1))) {
            args[a.groupValues[1].trim()] = value(a.groupValues[2].trim())
        }
        Call(n.groupValues[1], args, m.value)
    }.toList()

    /** Numbers and booleans as such (the model writes `9`, not `"9"`); everything else stays a string. */
    private fun value(v: String): Any? = try {
        val j = JsonParser.parseString(v)
        when {
            j is JsonPrimitive && j.isNumber -> if (v.contains('.')) j.asDouble else j.asLong
            j is JsonPrimitive && j.isBoolean -> j.asBoolean
            j is JsonPrimitive && j.isString -> j.asString
            else -> v
        }
    } catch (e: Exception) {
        v
    }

    fun withoutCalls(text: String): String = CALL.replace(text, "").trim()

    fun render(c: Call): String =
        if (c.args.isEmpty()) "${c.name}()"
        else c.name + "(" + c.args.entries.joinToString(", ") { (k, v) -> if (v is String) "$k=\"$v\"" else "$k=$v" } + ")"
}
