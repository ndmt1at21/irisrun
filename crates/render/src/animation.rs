//! Animations of layer properties in the style of `CABasicAnimation`: the
//! layer keeps its value, and frames show the animated one until the
//! animation ends.

use std::mem;

use skia_safe::{Color, Rect};

use crate::Layer;

/// A layer property and its value.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Value {
    Opacity(f32),
    Frame(Rect),
    Transform([f32; 6]),
    BackgroundColor(Color),
    CornerRadius(f32),
}

impl Value {
    pub(crate) fn same_property(self, other: Value) -> bool {
        mem::discriminant(&self) == mem::discriminant(&other)
    }

    fn components(self) -> [f32; 6] {
        match self {
            Value::Opacity(value) | Value::CornerRadius(value) => [value, 0.0, 0.0, 0.0, 0.0, 0.0],
            Value::Frame(rect) => [rect.left, rect.top, rect.width(), rect.height(), 0.0, 0.0],
            Value::Transform(transform) => transform,
            Value::BackgroundColor(color) => [
                color.a().into(),
                color.r().into(),
                color.g().into(),
                color.b().into(),
                0.0,
                0.0,
            ],
        }
    }

    fn with_components(self, c: [f32; 6]) -> Value {
        let channel = |value: f32| value.round().clamp(0.0, 255.0) as u8;
        match self {
            Value::Opacity(_) => Value::Opacity(c[0]),
            Value::CornerRadius(_) => Value::CornerRadius(c[0]),
            Value::Frame(_) => Value::Frame(Rect::from_xywh(c[0], c[1], c[2], c[3])),
            // ponytail: element-wise, which is right for moves and scales but
            // shrinks a rotation midway; decompose the matrix if that shows.
            Value::Transform(_) => Value::Transform(c),
            Value::BackgroundColor(_) => Value::BackgroundColor(Color::from_argb(
                channel(c[0]),
                channel(c[1]),
                channel(c[2]),
                channel(c[3]),
            )),
        }
    }

    fn lerp(self, to: Value, progress: f32) -> Value {
        let (from, to_components) = (self.components(), to.components());
        let mut c = [0.0; 6];
        for i in 0..6 {
            c[i] = from[i] + (to_components[i] - from[i]) * progress;
        }
        self.with_components(c)
    }

    pub(crate) fn apply(self, layer: &mut Layer) {
        match self {
            Value::Opacity(value) => layer.opacity = value.clamp(0.0, 1.0),
            Value::Frame(rect) => layer.frame = rect,
            Value::Transform(transform) => layer.transform = transform,
            Value::BackgroundColor(color) => layer.background_color = color,
            Value::CornerRadius(value) => layer.corner_radius = value.max(0.0),
        }
    }
}

/// A cubic Bézier curve from (0, 0) to (1, 1) that maps the time an
/// animation has run to how far it has got, as `CAMediaTimingFunction` does.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Timing {
    pub x1: f32,
    pub y1: f32,
    pub x2: f32,
    pub y2: f32,
}

impl Timing {
    pub const LINEAR: Timing = Timing::new(0.0, 0.0, 1.0, 1.0);
    pub const EASE_IN: Timing = Timing::new(0.42, 0.0, 1.0, 1.0);
    pub const EASE_OUT: Timing = Timing::new(0.0, 0.0, 0.58, 1.0);
    pub const EASE_IN_OUT: Timing = Timing::new(0.42, 0.0, 0.58, 1.0);
    /// What Core Animation uses when none is given.
    pub const DEFAULT: Timing = Timing::new(0.25, 0.1, 0.25, 1.0);

    pub const fn new(x1: f32, y1: f32, x2: f32, y2: f32) -> Timing {
        Timing { x1, y1, x2, y2 }
    }

    /// The progress at `time`, both from 0 to 1.
    pub fn progress(&self, time: f32) -> f32 {
        let time = time.clamp(0.0, 1.0);
        if self.x1 == self.y1 && self.x2 == self.y2 {
            return time; // control points on the diagonal: a straight line
        }
        // The curve's x and y as polynomials in its parameter t.
        let cx = 3.0 * self.x1.clamp(0.0, 1.0);
        let bx = 3.0 * (self.x2.clamp(0.0, 1.0) - self.x1.clamp(0.0, 1.0)) - cx;
        let ax = 1.0 - cx - bx;
        let cy = 3.0 * self.y1;
        let by = 3.0 * (self.y2 - self.y1) - cy;
        let ay = 1.0 - cy - by;
        let x = |t: f32| ((ax * t + bx) * t + cx) * t;

        // Newton's method converges in a few steps on most curves; bisection
        // covers the flat spots where it stalls.
        let mut t = time;
        for _ in 0..8 {
            let error = x(t) - time;
            let slope = (3.0 * ax * t + 2.0 * bx) * t + cx;
            if error.abs() < 1e-6 || slope.abs() < 1e-6 {
                break;
            }
            t -= error / slope;
        }
        if (x(t) - time).abs() >= 1e-6 || !(0.0..=1.0).contains(&t) {
            let (mut low, mut high) = (0.0, 1.0);
            t = time;
            for _ in 0..32 {
                if x(t) < time {
                    low = t;
                } else {
                    high = t;
                }
                t = (low + high) / 2.0;
            }
        }
        ((ay * t + by) * t + cy) * t
    }
}

impl Default for Timing {
    fn default() -> Self {
        Timing::DEFAULT
    }
}

/// A change of one property over time. The layer's own value shows before
/// the animation begins and after it ends, so set the layer to the final
/// value when adding one, as with Core Animation.
#[derive(Clone, Debug, PartialEq)]
pub struct Animation {
    pub from: Value,
    /// The same property as `from`.
    pub to: Value,
    /// In seconds.
    pub duration: f64,
    /// Seconds from when the animation is added to when it begins.
    pub delay: f64,
    pub timing: Timing,
    /// Times it plays: values up to 1 play it once, and infinity forever.
    pub repeat_count: f32,
    /// Plays backwards after each time forwards.
    pub autoreverses: bool,
    /// Shows `from` rather than the layer's own value until the animation
    /// begins, as Core Animation's backwards fill mode does.
    pub fills_backwards: bool,
}

impl Animation {
    pub fn new(from: Value, to: Value, duration: f64) -> Animation {
        Animation {
            from,
            to,
            duration,
            delay: 0.0,
            timing: Timing::DEFAULT,
            repeat_count: 1.0,
            autoreverses: false,
            fills_backwards: false,
        }
    }
}

pub(crate) struct Running {
    pub animation: Animation,
    /// Scene time it begins at.
    pub begin: f64,
}

impl Running {
    fn cycle(&self) -> f64 {
        let duration = self.animation.duration;
        if self.animation.autoreverses {
            2.0 * duration
        } else {
            duration
        }
    }

    pub fn finished(&self, time: f64) -> bool {
        let total = self.cycle() * f64::from(self.animation.repeat_count.max(1.0));
        self.animation.duration <= 0.0 || time - self.begin >= total
    }

    /// The value at `time`, or `None` outside the animation.
    pub fn value(&self, time: f64) -> Option<Value> {
        let elapsed = time - self.begin;
        if elapsed < 0.0 {
            let animation = &self.animation;
            return animation.fills_backwards.then_some(animation.from);
        }
        if self.finished(time) {
            return None;
        }
        let duration = self.animation.duration;
        let mut local = elapsed % self.cycle();
        if local > duration {
            local = 2.0 * duration - local;
        }
        let progress = self.animation.timing.progress((local / duration) as f32);
        Some(self.animation.from.lerp(self.animation.to, progress))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn timing_curves_match_core_animation() {
        assert_eq!(Timing::LINEAR.progress(0.3), 0.3);
        for timing in [Timing::EASE_IN, Timing::EASE_OUT, Timing::DEFAULT] {
            assert!(timing.progress(0.0).abs() < 1e-5);
            assert!((timing.progress(1.0) - 1.0).abs() < 1e-5);
        }
        // Ease-in-out is symmetric about the middle.
        let timing = Timing::EASE_IN_OUT;
        assert!((timing.progress(0.5) - 0.5).abs() < 1e-4);
        assert!((timing.progress(0.2) + timing.progress(0.8) - 1.0).abs() < 1e-4);
        assert!(Timing::EASE_IN.progress(0.5) < 0.5 && Timing::EASE_OUT.progress(0.5) > 0.5);
    }

    #[test]
    fn plays_repeats_and_reverses() {
        let mut animation = Animation::new(Value::Opacity(0.0), Value::Opacity(1.0), 1.0);
        animation.timing = Timing::LINEAR;
        animation.repeat_count = 2.0;
        animation.autoreverses = true;
        let running = Running {
            animation,
            begin: 10.0,
        };
        let at = |time: f64| running.value(time);
        assert_eq!(at(9.0), None, "before it begins");
        let filling = Running {
            animation: Animation {
                fills_backwards: true,
                ..running.animation.clone()
            },
            begin: 10.0,
        };
        assert_eq!(
            filling.value(9.0),
            Some(Value::Opacity(0.0)),
            "filling backwards"
        );
        assert_eq!(at(10.25), Some(Value::Opacity(0.25)));
        assert_eq!(at(11.25), Some(Value::Opacity(0.75)), "on its way back");
        assert_eq!(at(12.5), Some(Value::Opacity(0.5)), "the second time");
        assert_eq!(at(14.0), None, "after two forward and back cycles");
        assert!(running.finished(14.0) && !running.finished(13.9));
    }
}
