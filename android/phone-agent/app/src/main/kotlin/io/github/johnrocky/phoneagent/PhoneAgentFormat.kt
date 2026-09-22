package io.github.johnrocky.phoneagent

/** Prompt and output adaptation only. PhoneTools is the single source of tool definitions/actions. */
enum class PhoneAgentFormat {
    SPARK, QWENXML;

    fun systemText(localDateTime: String): String = when (this) {
        SPARK -> "The current date and time is $localDateTime. You control the user's phone through the tools; use them."
        QWENXML -> "You are a phone assistant. The current date and time is $localDateTime. " +
            "Use the provided tools to read the calendar, set alarms and timers, and add events. " +
            "Use get_current_datetime when you need the current local date and time."
    }

    fun extraContext(descriptions: List<Map<String, Any>>, noTools: Boolean, think: Boolean): Map<String, Any> =
        buildMap {
            if (!noTools) put("tools", descriptions)
            if (this@PhoneAgentFormat == QWENXML) put("enable_thinking", think)
        }

    fun parse(text: String): List<SparkToolCalls.Call> = when (this) {
        SPARK -> SparkToolCalls.parse(text)
        QWENXML -> QwenXmlToolCalls.parse(text).map { SparkToolCalls.Call(it.name, it.args, it.raw) }
    }

    fun withoutCalls(text: String): String = when (this) {
        SPARK -> SparkToolCalls.withoutCalls(text)
        QWENXML -> QwenXmlToolCalls.withoutCalls(text)
    }

    companion object {
        fun fromExtra(value: String?): PhoneAgentFormat = when (value ?: "spark") {
            "spark" -> SPARK
            "qwenxml" -> QWENXML
            else -> throw IllegalArgumentException("format must be spark or qwenxml")
        }
    }
}
