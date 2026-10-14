package dev.irisrun.device.v1alpha1

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals

class DelimitedTest {
    @Test
    fun sizeDelimitedEnvelopesRoundTrip() {
        val sent = listOf(
            hostMessage {
                input = input {
                    touch = touchInput {
                        touches += touchPoint {
                            id = 1
                            phase = TouchPhase.TOUCH_PHASE_BEGAN
                            x = 10.5f
                            y = 20f
                        }
                    }
                }
            },
            hostMessage { input = input { text = textEdit { commitText = "Tiếng Việt" } } },
        )

        val stream = ByteArrayOutputStream()
        sent.forEach { it.writeDelimitedTo(stream) }
        val bytes = ByteArrayInputStream(stream.toByteArray())
        val received = generateSequence { HostMessage.parseDelimitedFrom(bytes) }.toList()

        assertEquals(sent, received)
    }
}
