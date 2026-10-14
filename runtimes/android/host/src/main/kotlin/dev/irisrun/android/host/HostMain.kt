@file:JvmName("HostMain")

package dev.irisrun.android.host

import org.junit.runner.JUnitCore
import kotlin.system.exitProcess

/**
 * Runs an Android app on Robolectric for `irisrun start`.
 *
 * The CLI starts this class on the app's unit-test classpath and speaks the
 * Device Protocol over stdin and stdout. Robolectric only boots inside a test,
 * so the whole device session is one long-running JUnit test.
 */
fun main() {
    // stdout carries the protocol, so everything else printed goes to stderr,
    // which the CLI shows as logs.
    System.setOut(System.err)
    val result = JUnitCore().run(DeviceSession::class.java)
    result.failures.forEach { System.err.println(it.trace) }
    exitProcess(if (result.wasSuccessful()) 0 else 1)
}
