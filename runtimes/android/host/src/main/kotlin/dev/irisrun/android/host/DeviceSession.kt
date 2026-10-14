package dev.irisrun.android.host

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Looper
import android.util.Log
import com.google.protobuf.ByteString
import com.google.protobuf.Timestamp
import dev.irisrun.device.v1alpha1.AppState
import dev.irisrun.device.v1alpha1.DeviceKind
import dev.irisrun.device.v1alpha1.DeviceMessage
import dev.irisrun.device.v1alpha1.HostMessage
import dev.irisrun.device.v1alpha1.ImageFormat
import dev.irisrun.device.v1alpha1.LogLevel
import dev.irisrun.device.v1alpha1.Platform
import dev.irisrun.device.v1alpha1.appStatus
import dev.irisrun.device.v1alpha1.deviceInfo
import dev.irisrun.device.v1alpha1.deviceMessage
import dev.irisrun.device.v1alpha1.display
import dev.irisrun.device.v1alpha1.frame
import dev.irisrun.device.v1alpha1.logEntry
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.GraphicsMode
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowLog
import java.io.BufferedOutputStream
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.time.Duration
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@LooperMode(LooperMode.Mode.PAUSED)
class DeviceSession {
    @Test
    fun run() {
        System.getProperty("irisrun.qualifiers")?.let(RuntimeEnvironment::setQualifiers)
        Device(FileInputStream(FileDescriptor.`in`), FileOutputStream(FileDescriptor.out)).run()
    }
}

/**
 * The app on one simulated phone. Everything runs on the test thread, which is
 * Android's main thread; a reader thread only queues incoming messages.
 */
private class Device(input: InputStream, output: OutputStream) {
    private val output = BufferedOutputStream(output)
    private val inbox = LinkedBlockingQueue<HostMessage>()
    private val activities = ArrayDeque<ActivityController<out Activity>>()
    private val input = InputDispatcher()
    private val frames = FrameEncoder()
    private var logsSent = 0

    @Volatile private var hostConnected = true

    init {
        thread(isDaemon = true, name = "irisrun-reader") {
            try {
                while (true) inbox.put(HostMessage.parseDelimitedFrom(input) ?: break)
            } finally {
                hostConnected = false
            }
        }
    }

    fun run() {
        val app = RuntimeEnvironment.getApplication()
        send(deviceMessage { deviceInfo = describe() })
        send(status(AppState.APP_STATE_LAUNCHING))
        try {
            launch(app.packageManager.getLaunchIntentForPackage(app.packageName)
                ?: error("${app.packageName} has no launcher activity"))
            var last = System.nanoTime()
            while (hostConnected) {
                val frameStart = System.nanoTime()
                generateSequence { inbox.poll() }.forEach(::handle)
                // Robolectric's clock only moves when told to; keep it on real time.
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofNanos(frameStart - last))
                last = frameStart
                followActivities()
                forwardLogs()
                draw()
                val wait = FRAME_NANOS - (System.nanoTime() - frameStart)
                if (wait > 0) inbox.poll(wait, TimeUnit.NANOSECONDS)?.let(::handle)
            }
        } catch (crash: Throwable) {
            forwardLogs()
            send(status(AppState.APP_STATE_CRASHED, crash.stackTraceToString()))
        }
    }

    private fun handle(message: HostMessage) {
        val activity = activities.lastOrNull()?.get() ?: return
        when (message.payloadCase) {
            HostMessage.PayloadCase.INPUT -> input.dispatch(activity, message.input)
            else -> Log.w(TAG, "${message.payloadCase} is not supported yet")
        }
    }

    /** Plays the activity manager: starts what the app asked for and pops finished activities. */
    private fun followActivities() {
        val instrumentation = shadowOf(RuntimeEnvironment.getApplication())
        while (true) launch(instrumentation.nextStartedActivity ?: break)

        while (activities.lastOrNull()?.get()?.isFinishing == true) {
            activities.removeLast().pause().stop().destroy()
            activities.lastOrNull()?.restart()?.start()?.resume()
            if (activities.isEmpty()) send(status(AppState.APP_STATE_STOPPED))
        }
    }

    private fun launch(intent: Intent) {
        val className = intent.component?.className
        if (className == null) {
            Log.w(TAG, "Cannot open $intent yet: only activities of the app itself can start")
            return
        }
        val previous = activities.lastOrNull()?.pause()
        val activity = Class.forName(className).asSubclass(Activity::class.java)
        activities.addLast(Robolectric.buildActivity(activity, intent).setup())
        previous?.stop()
    }

    private fun draw() {
        val view = activities.lastOrNull()?.get()?.window?.decorView ?: return
        val image = frames.encode(view) ?: return
        send(deviceMessage {
            frame = frame {
                sequence = frames.sequence
                format = ImageFormat.IMAGE_FORMAT_PNG
                data = image
            }
        })
        if (frames.sequence == 1L) send(status(AppState.APP_STATE_FOREGROUND))
    }

    private fun forwardLogs() {
        val logs = ShadowLog.getLogs()
        for (item in logs.drop(logsSent)) {
            send(deviceMessage {
                log = logEntry {
                    time = now()
                    level = LOG_LEVELS.getOrDefault(item.type, LogLevel.LOG_LEVEL_INFO)
                    tag = item.tag.orEmpty()
                    message = listOfNotNull(item.msg, item.throwable?.stackTraceToString()).joinToString("\n")
                }
            })
        }
        logsSent = logs.size
    }

    private fun describe() = deviceInfo {
        val metrics = RuntimeEnvironment.getApplication().resources.displayMetrics
        platform = Platform.PLATFORM_ANDROID
        kind = DeviceKind.DEVICE_KIND_LOCAL_RUNTIME
        model = "Robolectric"
        osVersion = Build.VERSION.RELEASE
        display = display {
            widthPx = metrics.widthPixels
            heightPx = metrics.heightPixels
            scale = metrics.density
        }
    }

    private fun status(state: AppState, crashReport: String = "") = deviceMessage {
        appStatus = appStatus {
            this.state = state
            appId = RuntimeEnvironment.getApplication().packageName
            this.crashReport = crashReport
        }
    }

    private fun send(message: DeviceMessage) {
        message.writeDelimitedTo(output)
        output.flush()
    }

    private companion object {
        const val TAG = "irisrun"
        val FRAME_NANOS = TimeUnit.SECONDS.toNanos(1) / 30

        val LOG_LEVELS = mapOf(
            Log.VERBOSE to LogLevel.LOG_LEVEL_VERBOSE,
            Log.DEBUG to LogLevel.LOG_LEVEL_DEBUG,
            Log.INFO to LogLevel.LOG_LEVEL_INFO,
            Log.WARN to LogLevel.LOG_LEVEL_WARNING,
            Log.ERROR to LogLevel.LOG_LEVEL_ERROR,
            Log.ASSERT to LogLevel.LOG_LEVEL_FATAL,
        )

        fun now(): Timestamp {
            val millis = System.currentTimeMillis()
            return Timestamp.newBuilder().setSeconds(millis / 1000).setNanos((millis % 1000).toInt() * 1_000_000).build()
        }
    }
}

/** Draws the window into a bitmap and encodes it, skipping frames that did not change. */
private class FrameEncoder {
    private var previous: Bitmap? = null
    private var current: Bitmap? = null

    var sequence = 0L
        private set

    fun encode(view: android.view.View): ByteString? {
        if (view.width == 0 || view.height == 0) return null
        val bitmap = current?.takeIf { it.width == view.width && it.height == view.height }
            ?: Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(0)
        view.draw(Canvas(bitmap))
        if (previous?.sameAs(bitmap) == true) {
            current = bitmap
            return null
        }
        // Swap buffers: this frame becomes the one to compare the next against.
        current = previous
        previous = bitmap
        sequence++
        return ByteString.newOutput().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteString()
        }
    }
}
