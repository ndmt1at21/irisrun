//! Rust bindings for the Iris Device Protocol, generated from `proto/` by
//! `pnpm proto:generate`. See `device.proto` for how the messages flow.

pub mod device {
    pub mod v1alpha1 {
        include!("gen/irisrun/device/v1alpha1/irisrun.device.v1alpha1.rs");
    }
}

#[cfg(test)]
mod tests {
    use super::device::v1alpha1::{
        HostMessage, Input, TextEdit, TouchInput, TouchPhase, TouchPoint, host_message, input,
        text_edit,
    };
    use prost::Message;

    fn input(event: input::Event) -> HostMessage {
        HostMessage {
            payload: Some(host_message::Payload::Input(Input { event: Some(event) })),
        }
    }

    #[test]
    fn size_delimited_envelopes_round_trip() {
        let sent = vec![
            input(input::Event::Touch(TouchInput {
                touches: vec![TouchPoint {
                    id: 1,
                    phase: TouchPhase::Began.into(),
                    x: 10.5,
                    y: 20.0,
                }],
            })),
            input(input::Event::Text(TextEdit {
                edit: Some(text_edit::Edit::CommitText("Tiếng Việt".into())),
            })),
        ];

        let mut stream = Vec::new();
        for message in &sent {
            message.encode_length_delimited(&mut stream).unwrap();
        }
        let mut rest = stream.as_slice();
        let mut received = Vec::new();
        while !rest.is_empty() {
            received.push(HostMessage::decode_length_delimited(&mut rest).unwrap());
        }

        assert_eq!(received, sent);
    }
}
