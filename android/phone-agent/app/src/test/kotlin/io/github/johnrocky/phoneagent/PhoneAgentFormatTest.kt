package io.github.johnrocky.phoneagent

import org.junit.Assert.*
import org.junit.Test

class PhoneAgentFormatTest {
    @Test fun defaultSparkBehaviorIsPreserved() {
        val format = PhoneAgentFormat.fromExtra(null)
        assertEquals(PhoneAgentFormat.SPARK, format)
        assertEquals("The current date and time is Tuesday, 2026-09-22 08:45. You control the user's phone through the tools; use them.", format.systemText("Tuesday, 2026-09-22 08:45"))
        val calls = format.parse("<tool_call>set_alarm<arg_key>hour</arg_key><arg_value>8</arg_value></tool_call>")
        assertEquals(8L, calls.single().args["hour"])
        assertEquals(emptyMap<String, Any>(), format.extraContext(emptyList(), true, false))
        assertEquals(mapOf("tools" to emptyList<Map<String, Any>>()), format.extraContext(emptyList(), false, false))
    }

    @Test fun qwenPassesSameToolObjectsAndExplicitThinkingFlag() {
        val format = PhoneAgentFormat.fromExtra("qwenxml")
        val descriptions = listOf(mapOf<String, Any>("type" to "function", "function" to mapOf("name" to "get_current_datetime")))
        val context = format.extraContext(descriptions, false, false)
        assertSame(descriptions, context["tools"])
        assertEquals(false, context["enable_thinking"])
        assertEquals(mapOf("enable_thinking" to false), format.extraContext(descriptions, true, false))
        assertEquals(true, format.extraContext(descriptions, false, true)["enable_thinking"])
        assertTrue(format.systemText("now").contains("get_current_datetime"))
        assertFalse(format.systemText("now").contains("get_time"))
        assertEquals("8", format.parse("<tool_call><function=set_alarm><parameter=hour>8</parameter></function></tool_call>").single().args["hour"])
    }

    @Test(expected = IllegalArgumentException::class) fun invalidFormatFailsExplicitly() {
        PhoneAgentFormat.fromExtra("typo")
    }
}
