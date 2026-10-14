package dev.irisrun.android.host

import android.app.Activity
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.InputEvent
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.inputmethod.EditorInfo
import dev.irisrun.device.v1alpha1.Button
import dev.irisrun.device.v1alpha1.Input
import dev.irisrun.device.v1alpha1.KeyAction
import dev.irisrun.device.v1alpha1.KeyInput
import dev.irisrun.device.v1alpha1.TextEdit
import dev.irisrun.device.v1alpha1.TouchInput
import dev.irisrun.device.v1alpha1.TouchPhase

/**
 * Delivers Device Protocol input to the app the way the system would: input
 * events go through the window's ViewRootImpl, and text goes through the
 * focused view's InputConnection, as an input method's would.
 */
internal class InputDispatcher {
    private var downTime = 0L

    fun dispatch(activity: Activity, input: Input) {
        when (input.eventCase) {
            Input.EventCase.TOUCH -> touch(activity, input.touch)
            Input.EventCase.KEY -> key(activity, input.key)
            Input.EventCase.TEXT -> text(activity, input.text)
            Input.EventCase.BUTTON -> button(activity, input.button.button)
            else -> Unit
        }
    }

    // ponytail: one changed touch per event; split simultaneous changes for real multi-touch (P1-09).
    private fun touch(activity: Activity, input: TouchInput) {
        val touches = input.touchesList
        if (touches.isEmpty()) return
        val now = SystemClock.uptimeMillis()
        val changed = touches.indexOfFirst { it.phase != TouchPhase.TOUCH_PHASE_MOVED && it.phase != TouchPhase.TOUCH_PHASE_STATIONARY }
        val pointer = changed shl MotionEvent.ACTION_POINTER_INDEX_SHIFT
        val action = when (touches.getOrNull(changed)?.phase) {
            null -> MotionEvent.ACTION_MOVE
            TouchPhase.TOUCH_PHASE_BEGAN ->
                if (touches.size == 1) MotionEvent.ACTION_DOWN.also { downTime = now } else MotionEvent.ACTION_POINTER_DOWN or pointer
            TouchPhase.TOUCH_PHASE_ENDED ->
                if (touches.size == 1) MotionEvent.ACTION_UP else MotionEvent.ACTION_POINTER_UP or pointer
            else -> MotionEvent.ACTION_CANCEL
        }
        val properties = touches.map {
            MotionEvent.PointerProperties().apply {
                id = it.id and MAX_POINTER_ID
                toolType = MotionEvent.TOOL_TYPE_FINGER
            }
        }
        val coords = touches.map {
            MotionEvent.PointerCoords().apply {
                x = it.x
                y = it.y
                pressure = 1f
                size = 1f
            }
        }
        val event = MotionEvent.obtain(
            downTime, now, action, touches.size, properties.toTypedArray(), coords.toTypedArray(),
            0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0,
        )
        deliver(activity, event)
        event.recycle()
    }

    private fun key(activity: Activity, input: KeyInput) {
        val keyCode = keyCode(input.code)
        if (keyCode == null) {
            Log.w(TAG, "Unknown key ${input.code}")
            return
        }
        var meta = 0
        if (input.shift) meta = meta or KeyEvent.META_SHIFT_ON
        if (input.control) meta = meta or KeyEvent.META_CTRL_ON
        if (input.alt) meta = meta or KeyEvent.META_ALT_ON
        if (input.meta) meta = meta or KeyEvent.META_META_ON
        val action = if (input.action == KeyAction.KEY_ACTION_UP) KeyEvent.ACTION_UP else KeyEvent.ACTION_DOWN
        val now = SystemClock.uptimeMillis()
        deliver(activity, KeyEvent(now, now, action, keyCode, 0, meta, 0, 0, 0, InputDevice.SOURCE_KEYBOARD))
    }

    private fun text(activity: Activity, edit: TextEdit) {
        // A fresh connection per edit is fine: views keep the composing span in their own text.
        val connection = activity.currentFocus?.onCreateInputConnection(EditorInfo()) ?: return
        when (edit.editCase) {
            TextEdit.EditCase.COMMIT_TEXT -> connection.commitText(edit.commitText, 1)
            TextEdit.EditCase.SET_COMPOSING_TEXT -> connection.setComposingText(edit.setComposingText, 1)
            TextEdit.EditCase.DELETE_SURROUNDING_TEXT ->
                connection.deleteSurroundingText(edit.deleteSurroundingText.beforeLength, edit.deleteSurroundingText.afterLength)
            else -> Unit
        }
    }

    private fun button(activity: Activity, button: Button) {
        val keyCode = when (button) {
            Button.BUTTON_BACK -> KeyEvent.KEYCODE_BACK
            Button.BUTTON_VOLUME_UP -> KeyEvent.KEYCODE_VOLUME_UP
            Button.BUTTON_VOLUME_DOWN -> KeyEvent.KEYCODE_VOLUME_DOWN
            else -> {
                Log.w(TAG, "$button is not supported yet")
                return
            }
        }
        for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
            val now = SystemClock.uptimeMillis()
            deliver(activity, KeyEvent(now, now, action, keyCode, 0))
        }
    }

    /** Through ViewRootImpl, so back reaches OnBackInvokedDispatcher as on a real phone. */
    private fun deliver(activity: Activity, event: InputEvent) {
        activity.window.decorView.viewRootImpl?.dispatchInputEvent(event)
            ?: Log.w(TAG, "Dropped $event: the window is not attached")
    }

    private companion object {
        const val TAG = "irisrun"
        const val MAX_POINTER_ID = 31

        val NAMED_KEYS = mapOf(
            "Enter" to KeyEvent.KEYCODE_ENTER,
            "NumpadEnter" to KeyEvent.KEYCODE_NUMPAD_ENTER,
            "Backspace" to KeyEvent.KEYCODE_DEL,
            "Delete" to KeyEvent.KEYCODE_FORWARD_DEL,
            "Tab" to KeyEvent.KEYCODE_TAB,
            "Escape" to KeyEvent.KEYCODE_ESCAPE,
            "Space" to KeyEvent.KEYCODE_SPACE,
            "ArrowLeft" to KeyEvent.KEYCODE_DPAD_LEFT,
            "ArrowRight" to KeyEvent.KEYCODE_DPAD_RIGHT,
            "ArrowUp" to KeyEvent.KEYCODE_DPAD_UP,
            "ArrowDown" to KeyEvent.KEYCODE_DPAD_DOWN,
            "Home" to KeyEvent.KEYCODE_MOVE_HOME,
            "End" to KeyEvent.KEYCODE_MOVE_END,
        )

        /** Maps a W3C KeyboardEvent.code to an Android key code. */
        fun keyCode(code: String): Int? {
            NAMED_KEYS[code]?.let { return it }
            val char = code.removePrefix("Key").removePrefix("Digit").singleOrNull() ?: return null
            return when (char) {
                in 'A'..'Z' -> KeyEvent.KEYCODE_A + (char - 'A')
                in '0'..'9' -> KeyEvent.KEYCODE_0 + (char - '0')
                else -> null
            }
        }
    }
}
