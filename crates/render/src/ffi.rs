//! The C API declared in `include/irisrun_render.h`; see there for the
//! contract of each function.

// The C ABI hands over raw pointers. Every function checks them for null
// before use and trusts the caller for the rest, as C APIs do.
#![allow(unsafe_code)]

use std::ffi::{CStr, c_char};
use std::{ptr, slice};

use skia_safe::{Color, Rect};

use crate::{ImageFormat, Layer, LayerId, Scene, TextAlign, TextStyle};

const LAYER_NONE: LayerId = u64::MAX;

#[repr(C)]
pub struct IrisTextStyle {
    size: f32,
    weight: u16,
    color: u32,
    align: u32,
    max_lines: u32,
}

#[repr(C)]
pub struct IrisBytes {
    data: *mut u8,
    len: usize,
}

impl From<&IrisTextStyle> for TextStyle {
    fn from(style: &IrisTextStyle) -> Self {
        TextStyle {
            size: style.size,
            weight: style.weight,
            color: Color::new(style.color),
            align: match style.align {
                1 => TextAlign::Center,
                2 => TextAlign::Trailing,
                _ => TextAlign::Leading,
            },
            max_lines: style.max_lines as usize,
        }
    }
}

unsafe fn str<'a>(utf8: *const c_char) -> Option<&'a str> {
    if utf8.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(utf8) }.to_str().ok()
}

unsafe fn bytes<'a>(data: *const u8, len: usize) -> Option<&'a [u8]> {
    if data.is_null() {
        return None;
    }
    Some(unsafe { slice::from_raw_parts(data, len) })
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
    let (Some(scene), Some(data)) = (unsafe { scene.as_mut() }, unsafe { bytes(data, len) }) else {
        return false;
    };
    scene.add_font(data).is_some()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_root(scene: *const Scene) -> LayerId {
    unsafe { scene.as_ref() }.map_or(LAYER_NONE, Scene::root)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_measure_text(
    scene: *const Scene,
    utf8: *const c_char,
    style: *const IrisTextStyle,
    max_width: f32,
    width: *mut f32,
    height: *mut f32,
) -> bool {
    let (Some(scene), Some(text), Some(style)) =
        (unsafe { scene.as_ref() }, unsafe { str(utf8) }, unsafe {
            style.as_ref()
        })
    else {
        return false;
    };
    let size = scene.measure_text(text, &style.into(), max_width);
    unsafe {
        if let Some(width) = width.as_mut() {
            *width = size.width;
        }
        if let Some(height) = height.as_mut() {
            *height = size.height;
        }
    }
    true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_scene_encode(
    scene: *mut Scene,
    format: u32,
    quality: u8,
) -> IrisBytes {
    let format = match format {
        0 => ImageFormat::Png,
        1 => ImageFormat::Jpeg,
        _ => {
            return IrisBytes {
                data: ptr::null_mut(),
                len: 0,
            };
        }
    };
    match unsafe { scene.as_mut() }.and_then(|scene| scene.encode(format, quality)) {
        Some(encoded) => {
            let encoded = encoded.into_boxed_slice();
            let len = encoded.len();
            IrisBytes {
                data: Box::into_raw(encoded).cast(),
                len,
            }
        }
        None => IrisBytes {
            data: ptr::null_mut(),
            len: 0,
        },
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
pub unsafe extern "C" fn iris_layer_set_text(
    scene: *mut Scene,
    layer: LayerId,
    utf8: *const c_char,
    style: *const IrisTextStyle,
) -> bool {
    let (Some(scene), Some(text), Some(style)) =
        (unsafe { scene.as_mut() }, unsafe { str(utf8) }, unsafe {
            style.as_ref()
        })
    else {
        return false;
    };
    scene.set_text(layer, text, &style.into())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_set_image(
    scene: *mut Scene,
    layer: LayerId,
    data: *const u8,
    len: usize,
) -> bool {
    let (Some(scene), Some(data)) = (unsafe { scene.as_mut() }, unsafe { bytes(data, len) }) else {
        return false;
    };
    scene.set_image(layer, data)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn iris_layer_clear_content(scene: *mut Scene, layer: LayerId) -> bool {
    unsafe { scene.as_mut() }.is_some_and(|scene| scene.clear_content(layer))
}
