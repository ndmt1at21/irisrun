//! Device Protocol input, turned into scrcpy control messages.

use irisrun_protocol::device::v1alpha1::{
    Button, KeyAction, TouchPhase, input::Event, text_edit::Edit,
};

use crate::scrcpy::control::{self, Touch};

const KEYCODE_DEL: i32 = 67;

/// Messages for one input. Touches are in pixels of the video, which is
/// `size` large.
pub fn controls(
    input: &irisrun_protocol::device::v1alpha1::Input,
    size: (u32, u32),
) -> Vec<Vec<u8>> {
    let (width, height) = (size.0 as u16, size.1 as u16);
    match &input.event {
        Some(Event::Touch(touch)) => touch
            .touches
            .iter()
            .filter_map(|point| {
                let action = match point.phase() {
                    TouchPhase::Began => control::ACTION_DOWN,
                    TouchPhase::Moved => control::ACTION_MOVE,
                    TouchPhase::Ended => control::ACTION_UP,
                    TouchPhase::Cancelled => control::ACTION_CANCEL,
                    TouchPhase::Stationary | TouchPhase::Unspecified => return None,
                };
                Some(control::touch(&Touch {
                    action,
                    pointer_id: point.id.into(),
                    x: point.x.round() as i32,
                    y: point.y.round() as i32,
                    width,
                    height,
                }))
            })
            .collect(),
        Some(Event::Key(key)) => keycode(&key.code)
            .map(|keycode| {
                let mut meta = 0;
                for (on, flag) in [
                    (key.shift, 0x1),
                    (key.alt, 0x2),
                    (key.control, 0x1000),
                    (key.meta, 0x10000),
                ] {
                    if on {
                        meta |= flag;
                    }
                }
                vec![control::key(key.action() != KeyAction::Up, keycode, meta)]
            })
            .unwrap_or_default(),
        Some(Event::Text(text)) => match &text.edit {
            Some(Edit::CommitText(text)) if text.is_ascii() => vec![control::text(text)],
            // ponytail: one paste per commit races when commits come faster than
            // the app pastes; an irisrun IME on the device would take text directly.
            Some(Edit::CommitText(text)) => vec![control::paste(text)],
            // Composing text needs that IME too.
            Some(Edit::SetComposingText(_)) | None => Vec::new(),
            Some(Edit::DeleteSurroundingText(delete)) => (0..delete.before_length)
                .flat_map(|_| {
                    [
                        control::key(true, KEYCODE_DEL, 0),
                        control::key(false, KEYCODE_DEL, 0),
                    ]
                })
                .collect(),
        },
        Some(Event::Button(press)) => {
            let keycode = match press.button() {
                Button::Back => 4,
                Button::Home => 3,
                Button::AppSwitch => 187,
                Button::VolumeUp => 24,
                Button::VolumeDown => 25,
                Button::Power => 26,
                Button::Unspecified => return Vec::new(),
            };
            vec![
                control::key(true, keycode, 0),
                control::key(false, keycode, 0),
            ]
        }
        None => Vec::new(),
    }
}

/// Maps a W3C KeyboardEvent.code to an Android key code.
fn keycode(code: &str) -> Option<i32> {
    let named = match code {
        "Enter" => 66,
        "NumpadEnter" => 160,
        "Backspace" => KEYCODE_DEL,
        "Delete" => 112,
        "Tab" => 61,
        "Escape" => 111,
        "Space" => 62,
        "ArrowLeft" => 21,
        "ArrowRight" => 22,
        "ArrowUp" => 19,
        "ArrowDown" => 20,
        "Home" => 122,
        "End" => 123,
        _ => 0,
    };
    if named != 0 {
        return Some(named);
    }
    let rest = code
        .strip_prefix("Key")
        .or_else(|| code.strip_prefix("Digit"))?;
    match rest.as_bytes() {
        [c @ b'A'..=b'Z'] => Some(29 + i32::from(c - b'A')),
        [c @ b'0'..=b'9'] => Some(7 + i32::from(c - b'0')),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use irisrun_protocol::device::v1alpha1::{Input, TouchInput, TouchPoint};

    use super::*;

    #[test]
    fn maps_changed_touches_and_keys() {
        let touch = |phase: TouchPhase| TouchPoint {
            id: 0,
            phase: phase.into(),
            x: 10.4,
            y: 20.6,
        };
        let input = Input {
            event: Some(Event::Touch(TouchInput {
                touches: vec![touch(TouchPhase::Began), touch(TouchPhase::Stationary)],
            })),
        };
        let messages = controls(&input, (576, 1280));
        assert_eq!(messages.len(), 1, "stationary touches send nothing");
        assert_eq!(messages[0][1], control::ACTION_DOWN);
        assert_eq!(keycode("KeyA"), Some(29));
        assert_eq!(keycode("Digit9"), Some(16));
        assert_eq!(keycode("Backspace"), Some(67));
        assert_eq!(keycode("F13"), None);
    }
}
