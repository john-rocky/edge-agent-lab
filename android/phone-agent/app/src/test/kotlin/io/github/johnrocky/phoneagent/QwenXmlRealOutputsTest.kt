package io.github.johnrocky.phoneagent

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class QwenXmlRealOutputsTest(private val filename: String, private val expected: JsonObject) {
    @Test fun parsesRecordedModelOutput() {
        val raw = javaClass.getResource("/qwenxml/$filename")!!.readText()
        val calls = QwenXmlToolCalls.parse(raw)
        assertEquals(filename, 1, calls.size)
        assertEquals(expected["expected_name"].asString, calls.single().name)
        assertEquals(expected["expected_args"].asJsonObject.entrySet().associate { it.key to it.value.asString }, calls.single().args)
        assertFalse(QwenXmlToolCalls.hasUnparsedMarkup(raw))
    }

    companion object {
        @JvmStatic @Parameterized.Parameters(name = "{0}")
        fun fixtures(): Collection<Array<Any>> {
            val json = QwenXmlRealOutputsTest::class.java.getResource("/qwenxml/manifest.json")!!.readText()
            return JsonParser.parseString(json).asJsonArray.map {
                arrayOf(it.asJsonObject["file"].asString, it.asJsonObject)
            }
        }
    }
}
