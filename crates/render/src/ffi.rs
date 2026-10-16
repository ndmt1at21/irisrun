//! The C API declared in `include/irisrun_render.h`; see there for the
//! contract of each function.

// The C ABI hands over raw pointers. Every function checks them for null
// before use and trusts the caller for the rest, as C APIs do.
#![allow(unsafe_code)]

use std::ffi::{CStr, c_char};
use std::{ptr, slice};

use skia_safe::{Color, Image, PaintCap, PaintJoin, Path, PathBuilder, PathFillType, Point, Rect};

use crate::{
    Animation, ContentMode, Gradient, GradientKind, ImageFormat, Layer, LayerId, LayoutSolver,
    ParagraphStyle, Relation, Run, RunStyle, Scene, Shape, TextAlign, Timing, Value,
};

const LAYER_NONE: LayerId = u64::MAX;

const TEXT_ITALIC: u32 = 1;
const TEXT_UNDERLINE: u32 = 1 << 1;
const TEXT_STRIKETHROUGH: u32 = 1 << 2;

#[repr(C)]
pub struct IrisTextRun {
    start: usize,
    end: usize,
    size: f32,
    weight: u16,
    color: u32,
    traits: u32,
    letter_spacing: f32,
    baseline_offset: f32,
    background: u32,
}

#[repr(C)]
pub struct IrisParagraphStyle {
    align: u32,
    max_lines: u32,
    line_spacing: f32,
}

#[repr(C)]
pub struct IrisTextMetrics {
    width: f32,
    height: f32,
    first_baseline: f32,
    last_baseline: f32,
    line_count: u32,
    truncated: bool,
}

#[repr(C)]
pub struct IrisCaret {
    x: f32,
    y: f32,
    height: f32,
}

#[repr(C)]
pub struct IrisFontMetrics {
    ascender: f32,
    descender: f32,
    leading: f32,
    cap_height: f32,
    x_height: f32,
}

#[repr(C)]
pub struct IrisPathElement {
    verb: u32,
    points: [f32; 6],
}

#[repr(C)]
pub struct IrisShapeStyle {
    fill: u32,
    stroke: u32,
    line_width: f32,
    line_cap: u32,
    line_join: u32,
    miter_limit: f32,
    even_odd: bool,
    dashes: *const f32,
    dash_count: usize,
    dash_phase: f32,
}

#[repr(C)]
pub struct IrisGradient {
    kind: u32,
    colors: *const u32,
    locations: *const f32,
    count: usize,
    start_x: f32,
    start_y: f32,
    end_x: f32,
    end_y: f32,
    center_x: f32,
    center_y: f32,
    start_radius: f32,
    end_radius: f32,
    start_angle: f32,
    end_angle: f32,
}

#[repr(C)]
pub struct IrisAnimation {
    property: u32,
    from: [f32; 6],
    to: [f32; 6],
    from_color: u32,
    to_color: u32,
    duration: f64,
    delay: f64,
    timing: [f32; 4],
    repeat_count: f32,
    autoreverses: bool,
}

#[repr(C)]
pub struct IrisBytes {
    data: *mut u8,
    len: usize,
}

impl IrisBytes {
    const NONE: IrisBytes = IrisBytes {
        data: ptr::null_mut(),
        len: 0,
    };

    fn new(bytes: Option<Vec<u8>>) -> IrisBytes {
        let Some(bytes) = bytes else {
            return IrisBytes::NONE;
        };
        let bytes = bytes.into_boxed_slice();
        let len = bytes.len();
        IrisBytes {
            data: Box::into_raw(bytes).cast(),
            len,
        }
    }
}

/// A rendered frame; `Image` is immutable and safe to share.
pub struct IrisFrame(Image);

impl From<&IrisTextRun> for Run {
    fn from(run: &IrisTextRun) -> Self {
        Run {
            range: run.start..run.end,
            style: RunStyle {
                size: run.size,
                weight: run.weight,
                color: Color::new(run.color),
                italic: run.traits & TEXT_ITALIC != 0,
                underline: run.traits & TEXT_UNDERLINE != 0,
                strikethrough: run.traits & TEXT_STRIKETHROUGH != 0,
                letter_spacing: run.letter_spacing,
                baseline_offset: run.baseline_offset,
                background: Color::new(run.background),
            },
        }
    }
}

impl From<&IrisParagraphStyle> for ParagraphStyle {
    fn from(style: &IrisParagraphStyle) -> Self {
        ParagraphStyle {
            align: match style.align {
                1 => TextAlign::Center,
                2 => TextAlign::Trailing,
                _ => TextAlign::Leading,
            },
            max_lines: style.max_lines as usize,
            line_spacing: style.line_spacing,
        }
    }
}

unsafe fn str<'a>(utf8: *const c_char) -> Option<&'a str> {
    if utf8.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(utf8) }.to_str().ok()
}

/// An empty slice for a zero length, whatever the pointer.
unsafe fn items<'a, T>(data: *const T, len: usize) -> Option<&'a [T]> {
    match (len, data.is_null()) {
        (0, _) => Some(&[]),
        (_, true) => None,
        _ => Some(unsafe { slice::from_raw_parts(data, len) }),
    }
}

unsafe fn text<'a>(
    utf8: *const c_char,
    runs: *const IrisTextRun,
    run_count: usize,
    paragraph: *const IrisParagraphStyle,
) -> Option<(&'a str, Vec<Run>, ParagraphStyle)> {
    let text = unsafe { str(utf8) }?;
    let runs = unsafe { items(runs, run_count) }?
        .iter()
        .map(Run::from)
        .collect();
    let paragraph = unsafe { paragraph.as_ref() }
        .map(Into::into)
        .unwrap_or_default();
    Some((text, runs, paragraph))
}

unsafe fn path(elements: *const IrisPathElement, count: usize, even_odd: bool) -> Option<Path> {
    let mut path = PathBuilder::new();
    for element in unsafe { items(elements, count) }? {
        let p = element.points;
        match element.verb {
            0 => path.move_to((p[0], p[1])),
            1 => path.line_to((p[0], p[1])),
            2 => path.quad_to((p[0], p[1]), (p[2], p[3])),
            3 => path.cubic_to((p[0], p[1]), (p[2], p[3]), (p[4], p[5])),
            4 => path.close(),
            _ => return None,
        };
    }
    path.set_fill_type(if even_odd {
        PathFillType::EvenOdd
    } else {
        PathFillType::Winding
    });
    Some(path.detach())
}

unsafe fn with_layer(scene: *mut Scene, layer: LayerId, change: impl FnOnce(&mut Layer)) -> bool {
    match unsafe { scene.as_mut() }.and_then(|scene| scene.layer_mut(layer)) {
        Some(layer) => {
            change(layer);
            true
        }
        None => false,
    }
}

fn image_format(format: u32) -> Option<ImageFormat> {
    match format {
        0 => Some(ImageFormat::Png),
        1 => Some(ImageFormat::Jpeg),
        _ => None,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn iris_scene_new(width: f32, height: f32, scale: f32) -> *mut Scene {
    Box::into_raw(Box::new(Scene::new(width, height, scale)))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_free(scene: *mut Scene) {
    if !scene.is_null() {
        drop(unsafe { Box::from_raw(scene) });
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_resize(scene: *mut Scene, width: f32, height: f32, scale: f32) {
    if let Some(scene) = unsafe { scene.as_mut() } {
        scene.resize(width, height, scale);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_add_font(
    scene: *mut Scene,
    data: *const u8,
    len: usize,
) -> bool {
    let (Some(scene), Some(data)) = (unsafe { scene.as_mut() }, unsafe { items(data, len) }) else {
        return false;
    };
    scene.add_font(data).is_some()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_add_font_file(scene: *mut Scene, path: *const c_char) -> bool {
    let (Some(scene), Some(path)) = (unsafe { scene.as_mut() }, unsafe { str(path) }) else {
        return false;
    };
    scene.add_font_file(path).is_some()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_font_metrics(
    scene: *const Scene,
    size: f32,
    weight: u16,
    metrics: *mut IrisFontMetrics,
) -> bool {
    let (Some(scene), Some(out)) = (unsafe { scene.as_ref() }, unsafe { metrics.as_mut() }) else {
        return false;
    };
    let Some(metrics) = scene.font_metrics(size, weight) else {
        return false;
    };
    *out = IrisFontMetrics {
        ascender: metrics.ascender,
        descender: metrics.descender,
        leading: metrics.leading,
        cap_height: metrics.cap_height,
        x_height: metrics.x_height,
    };
    true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_root(scene: *const Scene) -> LayerId {
    unsafe { scene.as_ref() }.map_or(LAYER_NONE, Scene::root)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_measure_text(
    scene: *const Scene,
    utf8: *const c_char,
    runs: *const IrisTextRun,
    run_count: usize,
    paragraph: *const IrisParagraphStyle,
    max_width: f32,
    metrics: *mut IrisTextMetrics,
) -> bool {
    let (Some(scene), Some((text, runs, paragraph)), Some(out)) = (
        unsafe { scene.as_ref() },
        unsafe { text(utf8, runs, run_count, paragraph) },
        unsafe { metrics.as_mut() },
    ) else {
        return false;
    };
    let metrics = scene.measure_text(text, &runs, &paragraph, max_width);
    *out = IrisTextMetrics {
        width: metrics.width,
        height: metrics.height,
        first_baseline: metrics.first_baseline,
        last_baseline: metrics.last_baseline,
        line_count: metrics.line_count as u32,
        truncated: metrics.truncated,
    };
    true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_text_caret(
    scene: *const Scene,
    utf8: *const c_char,
    runs: *const IrisTextRun,
    run_count: usize,
    paragraph: *const IrisParagraphStyle,
    max_width: f32,
    offset: usize,
    caret: *mut IrisCaret,
) -> bool {
    let (Some(scene), Some((text, runs, paragraph)), Some(out)) = (
        unsafe { scene.as_ref() },
        unsafe { text(utf8, runs, run_count, paragraph) },
        unsafe { caret.as_mut() },
    ) else {
        return false;
    };
    let caret = scene.text_caret(text, &runs, &paragraph, max_width, offset);
    *out = IrisCaret {
        x: caret.x,
        y: caret.y,
        height: caret.height,
    };
    true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_text_offset_at(
    scene: *const Scene,
    utf8: *const c_char,
    runs: *const IrisTextRun,
    run_count: usize,
    paragraph: *const IrisParagraphStyle,
    max_width: f32,
    x: f32,
    y: f32,
) -> usize {
    let (Some(scene), Some((text, runs, paragraph))) = (unsafe { scene.as_ref() }, unsafe {
        text(utf8, runs, run_count, paragraph)
    }) else {
        return 0;
    };
    scene.text_offset_at(text, &runs, &paragraph, max_width, Point::new(x, y))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_image_size(
    data: *const u8,
    len: usize,
    width: *mut i32,
    height: *mut i32,
) -> bool {
    let (Some(bytes), Some(width), Some(height)) = (
        unsafe { items(data, len) },
        unsafe { width.as_mut() },
        unsafe { height.as_mut() },
    ) else {
        return false;
    };
    match Scene::image_size(bytes) {
        Some((w, h)) => {
            *width = w;
            *height = h;
            true
        }
        None => false,
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_set_time(scene: *mut Scene, seconds: f64) {
    if let Some(scene) = unsafe { scene.as_mut() } {
        scene.set_time(seconds);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_is_animating(scene: *const Scene) -> bool {
    unsafe { scene.as_ref() }.is_some_and(Scene::is_animating)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_hit_test(scene: *const Scene, x: f32, y: f32) -> LayerId {
    unsafe { scene.as_ref() }
        .and_then(|scene| scene.hit_test((x, y)))
        .unwrap_or(LAYER_NONE)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_render(scene: *mut Scene) -> *mut IrisFrame {
    match unsafe { scene.as_mut() } {
        Some(scene) => Box::into_raw(Box::new(IrisFrame(scene.render()))),
        None => ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_encode(
    scene: *mut Scene,
    format: u32,
    quality: u8,
) -> IrisBytes {
    match (unsafe { scene.as_mut() }, image_format(format)) {
        (Some(scene), Some(format)) => IrisBytes::new(scene.encode(format, quality)),
        _ => IrisBytes::NONE,
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_frame_encode(
    frame: *const IrisFrame,
    format: u32,
    quality: u8,
) -> IrisBytes {
    match (unsafe { frame.as_ref() }, image_format(format)) {
        (Some(frame), Some(format)) => IrisBytes::new(crate::encode(&frame.0, format, quality)),
        _ => IrisBytes::NONE,
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_frame_free(frame: *mut IrisFrame) {
    if !frame.is_null() {
        drop(unsafe { Box::from_raw(frame) });
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_bytes_free(bytes: IrisBytes) {
    if !bytes.data.is_null() {
        drop(unsafe { Box::from_raw(ptr::slice_from_raw_parts_mut(bytes.data, bytes.len)) });
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_new(scene: *mut Scene) -> LayerId {
    unsafe { scene.as_mut() }.map_or(LAYER_NONE, Scene::create_layer)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_destroy(scene: *mut Scene, layer: LayerId) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.destroy_layer(layer))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_add_sublayer(
    scene: *mut Scene,
    parent: LayerId,
    child: LayerId,
) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.add_sublayer(parent, child))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_insert_sublayer(
    scene: *mut Scene,
    parent: LayerId,
    child: LayerId,
    index: usize,
) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.insert_sublayer(parent, child, index))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_remove_from_parent(scene: *mut Scene, layer: LayerId) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.remove_from_parent(layer))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_frame(
    scene: *mut Scene,
    layer: LayerId,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
) -> bool {
    unsafe {
        with_layer(scene, layer, |layer| {
            layer.frame = Rect::from_xywh(x, y, width, height)
        })
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_transform(
    scene: *mut Scene,
    layer: LayerId,
    transform: *const f32,
) -> bool {
    if transform.is_null() {
        return false;
    }
    let transform: [f32; 6] = unsafe { *transform.cast() };
    unsafe { with_layer(scene, layer, |layer| layer.transform = transform) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_opacity(
    scene: *mut Scene,
    layer: LayerId,
    opacity: f32,
) -> bool {
    unsafe {
        with_layer(scene, layer, |layer| {
            layer.opacity = opacity.clamp(0.0, 1.0)
        })
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_hidden(
    scene: *mut Scene,
    layer: LayerId,
    hidden: bool,
) -> bool {
    unsafe { with_layer(scene, layer, |layer| layer.hidden = hidden) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_background_color(
    scene: *mut Scene,
    layer: LayerId,
    argb: u32,
) -> bool {
    unsafe {
        with_layer(scene, layer, |layer| {
            layer.background_color = Color::new(argb)
        })
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_corner_radius(
    scene: *mut Scene,
    layer: LayerId,
    radius: f32,
) -> bool {
    unsafe { with_layer(scene, layer, |layer| layer.corner_radius = radius.max(0.0)) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_border(
    scene: *mut Scene,
    layer: LayerId,
    width: f32,
    argb: u32,
) -> bool {
    unsafe {
        with_layer(scene, layer, |layer| {
            layer.border_width = width.max(0.0);
            layer.border_color = Color::new(argb);
        })
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_masks_to_bounds(
    scene: *mut Scene,
    layer: LayerId,
    masks: bool,
) -> bool {
    unsafe { with_layer(scene, layer, |layer| layer.masks_to_bounds = masks) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_mask(
    scene: *mut Scene,
    layer: LayerId,
    elements: *const IrisPathElement,
    count: usize,
    even_odd: bool,
) -> bool {
    let mask = match count {
        0 => None,
        _ => match unsafe { path(elements, count, even_odd) } {
            Some(path) => Some(path),
            None => return false,
        },
    };
    unsafe { with_layer(scene, layer, |layer| layer.mask = mask) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_shadow(
    scene: *mut Scene,
    layer: LayerId,
    argb: u32,
    dx: f32,
    dy: f32,
    radius: f32,
) -> bool {
    unsafe {
        with_layer(scene, layer, |layer| {
            layer.shadow_color = Color::new(argb);
            layer.shadow_offset = (dx, dy).into();
            layer.shadow_radius = radius.max(0.0);
        })
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_content_mode(
    scene: *mut Scene,
    layer: LayerId,
    mode: u32,
) -> bool {
    // The raw values of UIView.ContentMode; 3 is redraw, which stretches.
    let mode = match mode {
        1 => ContentMode::ScaleAspectFit,
        2 => ContentMode::ScaleAspectFill,
        4 => ContentMode::Center,
        5 => ContentMode::Top,
        6 => ContentMode::Bottom,
        7 => ContentMode::Left,
        8 => ContentMode::Right,
        9 => ContentMode::TopLeft,
        10 => ContentMode::TopRight,
        11 => ContentMode::BottomLeft,
        12 => ContentMode::BottomRight,
        _ => ContentMode::ScaleToFill,
    };
    unsafe { with_layer(scene, layer, |layer| layer.content_mode = mode) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_content_tint(
    scene: *mut Scene,
    layer: LayerId,
    argb: u32,
) -> bool {
    unsafe { with_layer(scene, layer, |layer| layer.content_tint = Color::new(argb)) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_text(
    scene: *mut Scene,
    layer: LayerId,
    utf8: *const c_char,
    runs: *const IrisTextRun,
    run_count: usize,
    paragraph: *const IrisParagraphStyle,
) -> bool {
    let (Some(scene), Some((text, runs, paragraph))) = (unsafe { scene.as_mut() }, unsafe {
        text(utf8, runs, run_count, paragraph)
    }) else {
        return false;
    };
    scene.set_text(layer, text, &runs, &paragraph)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_image(
    scene: *mut Scene,
    layer: LayerId,
    data: *const u8,
    len: usize,
    scale: f32,
) -> bool {
    let (Some(scene), Some(data)) = (unsafe { scene.as_mut() }, unsafe { items(data, len) }) else {
        return false;
    };
    scene.set_image(layer, data, scale)
}

#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)] // mirrors the C declaration
pub unsafe extern "C" fn iris_layer_set_image_pixels(
    scene: *mut Scene,
    layer: LayerId,
    width: i32,
    height: i32,
    rgba: *const u8,
    row_bytes: usize,
    premultiplied: bool,
    scale: f32,
) -> bool {
    let len = row_bytes.saturating_mul(height.max(0) as usize);
    let (Some(scene), Some(rgba)) = (unsafe { scene.as_mut() }, unsafe { items(rgba, len) }) else {
        return false;
    };
    scene.set_image_pixels(
        layer,
        (width, height),
        rgba,
        row_bytes,
        premultiplied,
        scale,
    )
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_shape(
    scene: *mut Scene,
    layer: LayerId,
    elements: *const IrisPathElement,
    count: usize,
    style: *const IrisShapeStyle,
) -> bool {
    let (Some(scene), Some(style)) = (unsafe { scene.as_mut() }, unsafe { style.as_ref() }) else {
        return false;
    };
    let (Some(path), Some(dashes)) = (unsafe { path(elements, count, style.even_odd) }, unsafe {
        items(style.dashes, style.dash_count)
    }) else {
        return false;
    };
    let shape = Shape {
        path,
        fill: Color::new(style.fill),
        stroke: Color::new(style.stroke),
        line_width: style.line_width,
        line_cap: match style.line_cap {
            1 => PaintCap::Round,
            2 => PaintCap::Square,
            _ => PaintCap::Butt,
        },
        line_join: match style.line_join {
            1 => PaintJoin::Round,
            2 => PaintJoin::Bevel,
            _ => PaintJoin::Miter,
        },
        miter_limit: style.miter_limit,
        dashes: dashes.to_vec(),
        dash_phase: style.dash_phase,
    };
    scene.set_shape(layer, &shape)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_gradient(
    scene: *mut Scene,
    layer: LayerId,
    gradient: *const IrisGradient,
) -> bool {
    let (Some(scene), Some(g)) = (unsafe { scene.as_mut() }, unsafe { gradient.as_ref() }) else {
        return false;
    };
    let locations = match g.locations.is_null() {
        true => Some(&[][..]),
        false => unsafe { items(g.locations, g.count) },
    };
    let (Some(colors), Some(locations)) = (unsafe { items(g.colors, g.count) }, locations) else {
        return false;
    };
    let center = Point::new(g.center_x, g.center_y);
    let kind = match g.kind {
        0 => GradientKind::Linear {
            start: Point::new(g.start_x, g.start_y),
            end: Point::new(g.end_x, g.end_y),
        },
        1 => GradientKind::Radial {
            center,
            start_radius: g.start_radius,
            end_radius: g.end_radius,
        },
        2 => GradientKind::Conic {
            center,
            start_angle: g.start_angle,
            end_angle: g.end_angle,
        },
        _ => return false,
    };
    let gradient = Gradient {
        kind,
        colors: colors.iter().map(|&argb| Color::new(argb)).collect(),
        locations: locations.to_vec(),
    };
    scene.set_gradient(layer, &gradient)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_clear_content(scene: *mut Scene, layer: LayerId) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.clear_content(layer))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_add_animation(
    scene: *mut Scene,
    layer: LayerId,
    animation: *const IrisAnimation,
) -> bool {
    let (Some(scene), Some(a)) = (unsafe { scene.as_mut() }, unsafe { animation.as_ref() }) else {
        return false;
    };
    let value = |v: [f32; 6], color: u32| match a.property {
        0 => Some(Value::Opacity(v[0])),
        1 => Some(Value::Frame(Rect::from_xywh(v[0], v[1], v[2], v[3]))),
        2 => Some(Value::Transform(v)),
        3 => Some(Value::BackgroundColor(Color::new(color))),
        4 => Some(Value::CornerRadius(v[0])),
        _ => None,
    };
    let (Some(from), Some(to)) = (value(a.from, a.from_color), value(a.to, a.to_color)) else {
        return false;
    };
    let [x1, y1, x2, y2] = a.timing;
    scene.add_animation(
        layer,
        Animation {
            from,
            to,
            duration: a.duration,
            delay: a.delay,
            timing: Timing::new(x1, y1, x2, y2),
            repeat_count: a.repeat_count,
            autoreverses: a.autoreverses,
        },
    )
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_remove_animations(scene: *mut Scene, layer: LayerId) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.remove_animations(layer))
}

// ---- Layout

#[repr(C)]
pub struct IrisLayoutTerm {
    variable: u32,
    coefficient: f64,
}

#[unsafe(no_mangle)]
pub extern "C" fn iris_layout_solver_new() -> *mut LayoutSolver {
    Box::into_raw(Box::new(LayoutSolver::new()))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layout_solver_free(solver: *mut LayoutSolver) {
    if !solver.is_null() {
        drop(unsafe { Box::from_raw(solver) });
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layout_variable_new(solver: *mut LayoutSolver) -> u32 {
    unsafe { solver.as_mut() }.map_or(u32::MAX, LayoutSolver::add_variable)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layout_add(
    solver: *mut LayoutSolver,
    terms: *const IrisLayoutTerm,
    count: usize,
    constant: f64,
    relation: i32,
    strength: f64,
) -> u64 {
    let (Some(solver), Some(terms)) = (unsafe { solver.as_mut() }, unsafe { items(terms, count) })
    else {
        return 0;
    };
    let relation = match relation {
        -1 => Relation::LessOrEqual,
        0 => Relation::Equal,
        1 => Relation::GreaterOrEqual,
        _ => return 0,
    };
    let terms: Vec<_> = terms
        .iter()
        .map(|term| (term.variable, term.coefficient))
        .collect();
    solver
        .add(&terms, constant, relation, strength)
        .unwrap_or(0)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layout_remove(solver: *mut LayoutSolver, constraint: u64) -> bool {
    unsafe { solver.as_mut() }.is_some_and(|solver| solver.remove(constraint))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layout_value(solver: *const LayoutSolver, variable: u32) -> f64 {
    unsafe { solver.as_ref() }.map_or(0.0, |solver| solver.value(variable))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The structs Swift and C fill in reach Rust intact.
    #[test]
    fn passes_runs_paths_and_gradients_across_the_c_api() {
        let scene = iris_scene_new(100.0, 100.0, 1.0);
        unsafe {
            let layer = iris_layer_new(scene);
            let root = iris_scene_root(scene);
            assert!(iris_layer_add_sublayer(scene, root, layer));
            assert!(iris_layer_set_frame(scene, layer, 0.0, 0.0, 100.0, 100.0));

            let fonts = std::path::PathBuf::from(std::env::var_os("HOME").unwrap())
                .join(".irisrun/fonts/Inter.ttf");
            let fonts = std::ffi::CString::new(fonts.to_str().unwrap()).unwrap();
            assert!(
                iris_scene_add_font_file(scene, fonts.as_ptr()),
                "run crates/render/fetch-fonts.sh"
            );
            let text = c"Iris";
            let run = IrisTextRun {
                start: 0,
                end: 4,
                size: 20.0,
                weight: 700,
                color: 0xFF00_0000,
                traits: TEXT_UNDERLINE,
                letter_spacing: 1.0,
                baseline_offset: 0.0,
                background: 0,
            };
            let paragraph = IrisParagraphStyle {
                align: 1,
                max_lines: 1,
                line_spacing: 0.0,
            };
            let mut metrics = std::mem::zeroed::<IrisTextMetrics>();
            assert!(iris_scene_measure_text(
                scene,
                text.as_ptr(),
                &run,
                1,
                &paragraph,
                f32::INFINITY,
                &mut metrics
            ));
            assert_eq!(metrics.line_count, 1);
            assert!(metrics.width > 0.0 && metrics.first_baseline > 0.0);
            let mut caret = IrisCaret {
                x: -1.0,
                y: -1.0,
                height: 0.0,
            };
            let end = text.count_bytes();
            assert!(iris_scene_text_caret(
                scene,
                text.as_ptr(),
                &run,
                1,
                &paragraph,
                f32::INFINITY,
                end,
                &mut caret
            ));
            assert!((caret.x - metrics.width).abs() < 1.0 && caret.height > 0.0);
            assert_eq!(
                iris_scene_text_offset_at(
                    scene,
                    text.as_ptr(),
                    &run,
                    1,
                    &paragraph,
                    f32::INFINITY,
                    1000.0,
                    5.0
                ),
                end
            );
            assert!(iris_layer_set_text(
                scene,
                layer,
                text.as_ptr(),
                &run,
                1,
                ptr::null()
            ));

            let triangle = [
                IrisPathElement {
                    verb: 0,
                    points: [0.0, 100.0, 0.0, 0.0, 0.0, 0.0],
                },
                IrisPathElement {
                    verb: 1,
                    points: [50.0, 0.0, 0.0, 0.0, 0.0, 0.0],
                },
                IrisPathElement {
                    verb: 1,
                    points: [100.0, 100.0, 0.0, 0.0, 0.0, 0.0],
                },
                IrisPathElement {
                    verb: 4,
                    points: [0.0; 6],
                },
            ];
            let style = IrisShapeStyle {
                fill: 0xFF00_FF00,
                stroke: 0,
                line_width: 1.0,
                line_cap: 0,
                line_join: 0,
                miter_limit: 10.0,
                even_odd: false,
                dashes: ptr::null(),
                dash_count: 0,
                dash_phase: 0.0,
            };
            assert!(iris_layer_set_shape(
                scene,
                layer,
                triangle.as_ptr(),
                4,
                &style
            ));
            let mut bad = triangle;
            bad[1].verb = 9;
            assert!(!iris_layer_set_shape(scene, layer, bad.as_ptr(), 4, &style));
            let frame = iris_scene_render(scene);
            let pixmap = (*frame).0.peek_pixels().unwrap();
            assert_eq!(pixmap.get_color((50, 80)), Color::GREEN);
            assert_eq!(
                pixmap.get_color((5, 5)),
                Color::BLACK,
                "no layer draws there"
            );
            let jpeg = iris_frame_encode(frame, 1, 80);
            assert!(!jpeg.data.is_null() && jpeg.len > 0);
            iris_bytes_free(jpeg);
            iris_frame_free(frame);

            let colors = [0xFFFF_0000, 0xFF00_00FF];
            let mut gradient = IrisGradient {
                kind: 0,
                colors: colors.as_ptr(),
                locations: ptr::null(),
                count: 2,
                start_x: 0.0,
                start_y: 0.0,
                end_x: 100.0,
                end_y: 0.0,
                center_x: 0.0,
                center_y: 0.0,
                start_radius: 0.0,
                end_radius: 0.0,
                start_angle: 0.0,
                end_angle: 0.0,
            };
            assert!(iris_layer_set_gradient(scene, layer, &gradient));
            gradient.kind = 7;
            assert!(!iris_layer_set_gradient(scene, layer, &gradient));

            let fade = IrisAnimation {
                property: 3,
                from: [0.0; 6],
                to: [0.0; 6],
                from_color: 0xFFFF_FFFF,
                to_color: 0xFF00_0000,
                duration: 1.0,
                delay: 0.0,
                timing: [0.0, 0.0, 1.0, 1.0],
                repeat_count: 1.0,
                autoreverses: false,
            };
            assert!(iris_layer_add_animation(scene, layer, &fade));
            assert!(iris_scene_is_animating(scene));
            assert_eq!(iris_scene_hit_test(scene, 50.0, 50.0), layer);
            iris_scene_free(scene);
        }
    }

    #[test]
    fn layout_solver_through_the_c_api() {
        unsafe {
            let solver = iris_layout_solver_new();
            let x = iris_layout_variable_new(solver);
            let terms = [IrisLayoutTerm {
                variable: x,
                coefficient: 2.0,
            }];
            let constraint = iris_layout_add(solver, terms.as_ptr(), 1, -10.0, 1, crate::REQUIRED);
            assert_ne!(constraint, 0);
            assert_eq!(iris_layout_value(solver, x), 5.0);
            assert_eq!(
                iris_layout_add(solver, terms.as_ptr(), 1, 0.0, 2, crate::REQUIRED),
                0
            );
            assert_eq!(
                iris_layout_add(solver, ptr::null(), 1, 0.0, 0, crate::REQUIRED),
                0
            );
            assert!(iris_layout_remove(solver, constraint));
            assert!(!iris_layout_remove(solver, constraint));
            assert_eq!(iris_layout_variable_new(ptr::null_mut()), u32::MAX);
            iris_layout_solver_free(solver);
        }
    }
}
