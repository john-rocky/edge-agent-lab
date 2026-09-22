package io.github.johnrocky.phoneagent

import org.junit.Assert.*
import org.junit.Test

class QwenXmlToolCallsTest {
    private fun call(body: String) = "<tool_call>\n$body\n</tool_call>"

    @Test fun multipleCallsBlankLinesCrLfAndPrefix() {
        val raw = "Let me check.\r\n" + call("\n<function=get_current_datetime>\n\n</function>\n") +
            "\r\n\r\n" + call("<function=set_alarm>\n<parameter=hour>\n8\n</parameter>\n<parameter=minute>10</parameter>\n<parameter=label>Train</parameter>\n</function>")
        val crlf = raw.replace("\r\n", "\n").replace("\n", "\r\n")
        val calls = QwenXmlToolCalls.parse(crlf)
        assertEquals(listOf("get_current_datetime", "set_alarm"), calls.map { it.name })
        assertTrue(calls[0].args.isEmpty())
        assertEquals(mapOf("hour" to "8", "minute" to "10", "label" to "Train"), calls[1].args)
        assertEquals("Let me check.", QwenXmlToolCalls.withoutCalls(crlf))
        assertFalse(QwenXmlToolCalls.hasUnparsedMarkup(crlf))
    }

    @Test fun multilineValuesAndLiteralBracesArePreserved() {
        val value = "First line\r\n  Second {line}: [1, 2]\r\nA & B < C"
        val raw = call("<function=example.function-name><parameter=some_key>\r\n$value\r\n</parameter></function>")
        assertEquals(value, QwenXmlToolCalls.parse(raw).single().args["some_key"])
    }

    @Test fun stringsAreNotJsonCoerced() {
        val raw = call("<function=f><parameter=a>08</parameter><parameter=b>false</parameter><parameter=c>\"quoted\"</parameter><parameter=d>{\"x\":1}</parameter><parameter=e> </parameter></function>")
        assertEquals(mapOf("a" to "08", "b" to "false", "c" to "\"quoted\"", "d" to "{\"x\":1}", "e" to ""), QwenXmlToolCalls.parse(raw).single().args)
    }

    @Test fun malformedBlocksDoNotProducePartialActions() {
        val bodies = listOf(
            "<function=set_alarm><parameter=hour>8</function>",
            "<function=set_alarm><parameter=hour>8</parameter>",
            "<function=set_alarm><parameter=hour>8</parameter><parameter=hour>9</parameter></function>",
            "<function=><parameter=hour>8</parameter></function>",
            "<function=9bad></function>",
            "<function=f>stray text</function>",
            "<function=f><parameter=bad key>8</parameter></function>",
            "<function=f><parameter=a><parameter=b>8</parameter></function>",
            "<function=f></function>extra",
            "<function=f></function><function=g></function>",
        )
        for (body in bodies) {
            val raw = call(body)
            assertTrue(raw, QwenXmlToolCalls.parse(raw).isEmpty())
            assertEquals(raw, QwenXmlToolCalls.withoutCalls(raw))
            assertTrue(raw, QwenXmlToolCalls.hasUnparsedMarkup(raw))
        }
    }

    @Test fun truncationRemainsVisible() {
        val raw = "<tool_call><function=set_alarm><parameter=hour>8</parameter></function>"
        assertTrue(QwenXmlToolCalls.parse(raw).isEmpty())
        assertTrue(QwenXmlToolCalls.hasUnparsedMarkup(raw))
        assertEquals(raw, QwenXmlToolCalls.withoutCalls(raw))
    }

    @Test fun validCallAfterMalformedBlockIsRecoverableButTurnIsFlagged() {
        val raw = call("broken") + call("<function=get_current_datetime></function>")
        assertEquals("get_current_datetime", QwenXmlToolCalls.parse(raw).single().name)
        assertTrue(QwenXmlToolCalls.hasUnparsedMarkup(raw))
    }

    @Test fun nestedBlocksLeaveTheMalformedPrefixVisible() {
        val raw = "<tool_call><function=bad>" + call("<function=get_current_datetime></function>")
        assertEquals("get_current_datetime", QwenXmlToolCalls.parse(raw).single().name)
        assertTrue(QwenXmlToolCalls.hasUnparsedMarkup(raw))
    }

    @Test fun ordinaryAnswerHasNoCalls() {
        assertTrue(QwenXmlToolCalls.parse("There is a 15-minute clash.").isEmpty())
        assertFalse(QwenXmlToolCalls.hasUnparsedMarkup("There is a 15-minute clash."))
    }
}
