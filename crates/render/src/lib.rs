//! OpenKit's render core: a retained layer tree in the style of Core
//! Animation's `CALayer`, drawn with Skia on the CPU into frames.
//!
//! OpenKit's SwiftUI and UIKit backends keep a [`Scene`] per window and
//! mirror their views into its layers, from Swift through the C API in
//! `include/irisrun_render.h`. Geometry is in points, as in UIKit; a frame
//! has `scale` pixels per point.

mod ffi;
mod text;

use skia_safe::textlayout::Paragraph;
use skia_safe::{
    Canvas, ClipOp, Color, FilterMode, Image, Matrix, MipmapMode, Paint, PaintStyle, RRect, Rect,
    SamplingOptions, Size, Surface, jpeg_encoder, png_encoder, surfaces,
};

use text::Fonts;
pub use text::{TextAlign, TextStyle};

/// Identifies a layer in its scene. Ids of destroyed layers are never valid
/// again, so a stale id is an error, not another layer.
pub type LayerId = u64;

/// What a layer looks like. Changes show in the next frame; nothing animates
/// yet.
#[derive(Clone, Debug, PartialEq)]
pub struct Layer {
    /// Position and size in the parent's coordinates, in points.
    pub frame: Rect,
    /// An affine transform about the layer's center, as `[a, b, c, d, tx,
    /// ty]` in the order of `CGAffineTransform`.
    pub transform: [f32; 6],
    /// Applies to the layer and its sublayers as one group.
    pub opacity: f32,
    pub hidden: bool,
    pub background_color: Color,
    pub corner_radius: f32,
    /// Drawn inside the bounds, above content and sublayers.
    pub border_width: f32,
    pub border_color: Color,
    /// Clips content and sublayers to the rounded bounds.
    pub masks_to_bounds: bool,
}

const IDENTITY: [f32; 6] = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

impl Default for Layer {
    fn default() -> Self {
        Layer {
            frame: Rect::new_empty(),
            transform: IDENTITY,
            opacity: 1.0,
            hidden: false,
            background_color: Color::TRANSPARENT,
            corner_radius: 0.0,
            border_width: 0.0,
            border_color: Color::TRANSPARENT,
            masks_to_bounds: false,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ImageFormat {
    Png,
    Jpeg,
}

enum Content {
    None,
    /// Laid out again when the layer's width changes.
    Text {
        paragraph: Paragraph,
        width: f32,
    },
    /// Stretched to the layer's bounds.
    Image(Image),
}

struct Node {
    layer: Layer,
    content: Content,
    parent: Option<LayerId>,
    sublayers: Vec<LayerId>,
}

struct Slot {
    generation: u32,
    node: Option<Node>,
}

/// The layers of one window. Not thread-safe: use it from one thread.
pub struct Scene {
    slots: Vec<Slot>,
    free: Vec<u32>,
    root: LayerId,
    size: Size,
    scale: f32,
    fonts: Fonts,
    surface: Option<Surface>,
}

impl Scene {
    /// A scene `width` × `height` points large, with an empty root layer
    /// that fills it.
    pub fn new(width: f32, height: f32, scale: f32) -> Scene {
        let mut scene = Scene {
            slots: Vec::new(),
            free: Vec::new(),
            root: 0,
            size: Size::new(width, height),
            scale,
            fonts: Fonts::new(),
            surface: None,
        };
        scene.root = scene.create_layer();
        scene.resize(width, height, scale);
        scene
    }

    pub fn root(&self) -> LayerId {
        self.root
    }

    pub fn resize(&mut self, width: f32, height: f32, scale: f32) {
        self.size = Size::new(width, height);
        self.scale = scale;
        let (root, frame) = (self.root, Rect::from_size(self.size));
        if let Some(layer) = self.layer_mut(root) {
            layer.frame = frame;
        }
    }

    /// Adds a TrueType or OpenType font and returns its family name, or
    /// `None` if the data is not a font. Fonts added first are tried first.
    pub fn add_font(&mut self, data: &[u8]) -> Option<String> {
        self.fonts.add(data)
    }

    /// A new layer, not in the tree until added to a parent.
    pub fn create_layer(&mut self) -> LayerId {
        let node = Node {
            layer: Layer::default(),
            content: Content::None,
            parent: None,
            sublayers: Vec::new(),
        };
        let index = match self.free.pop() {
            Some(index) => index,
            None => {
                self.slots.push(Slot {
                    generation: 0,
                    node: None,
                });
                (self.slots.len() - 1) as u32
            }
        };
        let slot = &mut self.slots[index as usize];
        slot.node = Some(node);
        u64::from(slot.generation) << 32 | u64::from(index)
    }

    /// Destroys a layer. Its sublayers stay alive, without a parent, since
    /// their owners still hold their ids. The root cannot be destroyed.
    pub fn destroy_layer(&mut self, id: LayerId) -> bool {
        if id == self.root || self.node(id).is_none() {
            return false;
        }
        self.remove_from_parent(id);
        let index = id as u32;
        let slot = &mut self.slots[index as usize];
        let node = slot.node.take().expect("checked above");
        slot.generation = slot.generation.wrapping_add(1);
        self.free.push(index);
        for child in node.sublayers {
            if let Some(child) = self.node_mut(child) {
                child.parent = None;
            }
        }
        true
    }

    pub fn layer(&self, id: LayerId) -> Option<&Layer> {
        self.node(id).map(|node| &node.layer)
    }

    pub fn layer_mut(&mut self, id: LayerId) -> Option<&mut Layer> {
        self.node_mut(id).map(|node| &mut node.layer)
    }

    pub fn sublayers(&self, id: LayerId) -> &[LayerId] {
        self.node(id).map_or(&[], |node| &node.sublayers)
    }

    /// Makes `child` the last sublayer of `parent`.
    pub fn add_sublayer(&mut self, parent: LayerId, child: LayerId) -> bool {
        self.insert_sublayer(parent, child, usize::MAX)
    }

    /// Moves `child` to `index` among the sublayers of `parent`, or to the
    /// end if `index` is past it. Fails if that would make a cycle.
    pub fn insert_sublayer(&mut self, parent: LayerId, child: LayerId, index: usize) -> bool {
        if child == self.root || self.node(parent).is_none() || self.node(child).is_none() {
            return false;
        }
        let mut ancestor = Some(parent);
        while let Some(id) = ancestor {
            if id == child {
                return false;
            }
            ancestor = self.node(id).and_then(|node| node.parent);
        }
        self.remove_from_parent(child);
        let sublayers = &mut self.node_mut(parent).expect("checked above").sublayers;
        sublayers.insert(index.min(sublayers.len()), child);
        self.node_mut(child).expect("checked above").parent = Some(parent);
        true
    }

    pub fn remove_from_parent(&mut self, id: LayerId) -> bool {
        let Some(parent) = self.node_mut(id).and_then(|node| node.parent.take()) else {
            return false;
        };
        if let Some(parent) = self.node_mut(parent) {
            parent.sublayers.retain(|&sublayer| sublayer != id);
        }
        true
    }

    pub fn set_text(&mut self, id: LayerId, text: &str, style: &TextStyle) -> bool {
        let paragraph = self.fonts.paragraph(text, style);
        self.set_content(
            id,
            Content::Text {
                paragraph,
                width: f32::NAN,
            },
        )
    }

    /// Shows a PNG, JPEG, WebP, GIF or BMP image. Fails if it cannot be
    /// decoded.
    pub fn set_image(&mut self, id: LayerId, encoded: &[u8]) -> bool {
        let Some(image) = Image::from_encoded(skia_safe::Data::new_copy(encoded)) else {
            return false;
        };
        self.set_content(id, Content::Image(image))
    }

    pub fn clear_content(&mut self, id: LayerId) -> bool {
        self.set_content(id, Content::None)
    }

    /// The size text takes, in points, when its lines may be up to
    /// `max_width` wide. Layout calls this to size text views.
    pub fn measure_text(&self, text: &str, style: &TextStyle, max_width: f32) -> Size {
        let mut paragraph = self.fonts.paragraph(text, style);
        paragraph.layout(max_width);
        Size::new(paragraph.longest_line().ceil(), paragraph.height().ceil())
    }

    /// Draws the tree into a frame of `size × scale` pixels.
    pub fn render(&mut self) -> Image {
        for slot in &mut self.slots {
            if let Some(Node {
                layer,
                content: Content::Text { paragraph, width },
                ..
            }) = &mut slot.node
                && *width != layer.frame.width()
            {
                paragraph.layout(layer.frame.width());
                *width = layer.frame.width();
            }
        }

        let pixels = (
            ((self.size.width * self.scale).round() as i32).max(1),
            ((self.size.height * self.scale).round() as i32).max(1),
        );
        let mut surface = self
            .surface
            .take()
            .filter(|surface| (surface.width(), surface.height()) == pixels)
            .unwrap_or_else(|| surfaces::raster_n32_premul(pixels).expect("a non-empty surface"));
        let canvas = surface.canvas();
        // What shows where no layer draws, as in an empty UIWindow.
        canvas.clear(Color::BLACK);
        canvas.save();
        canvas.scale((self.scale, self.scale));
        self.draw(self.root, canvas);
        canvas.restore();
        let image = surface.image_snapshot();
        self.surface = Some(surface);
        image
    }

    /// Renders a frame and encodes it. `quality` (0–100) applies to JPEG.
    pub fn encode(&mut self, format: ImageFormat, quality: u8) -> Option<Vec<u8>> {
        let image = self.render();
        let pixmap = image.peek_pixels()?;
        let mut out = Vec::new();
        let encoded = match format {
            ImageFormat::Png => png_encoder::encode(&pixmap, &mut out, &Default::default()),
            ImageFormat::Jpeg => jpeg_encoder::encode(
                &pixmap,
                &mut out,
                &jpeg_encoder::Options {
                    quality: quality.min(100).into(),
                    ..Default::default()
                },
            ),
        };
        encoded.then_some(out)
    }

    fn draw(&self, id: LayerId, canvas: &Canvas) {
        let Some(node) = self.node(id) else { return };
        let layer = &node.layer;
        if layer.hidden || layer.opacity <= 0.0 {
            return;
        }
        let saved = canvas.save();
        canvas.translate((layer.frame.left, layer.frame.top));
        let size = layer.frame.size();
        if layer.transform != IDENTITY {
            let center = (size.width / 2.0, size.height / 2.0);
            canvas.translate(center);
            canvas.concat(&Matrix::from_affine(&layer.transform));
            canvas.translate((-center.0, -center.1));
        }
        if layer.opacity < 1.0 {
            canvas.save_layer_alpha_f(None, layer.opacity);
        }

        let bounds = Rect::from_size(size);
        let shape = RRect::new_rect_xy(bounds, layer.corner_radius, layer.corner_radius);
        if layer.background_color.a() > 0 {
            canvas.draw_rrect(shape, &paint(layer.background_color));
        }
        if layer.masks_to_bounds {
            canvas.clip_rrect(shape, ClipOp::Intersect, true);
        }
        match &node.content {
            Content::None => {}
            Content::Text { paragraph, .. } => paragraph.paint(canvas, (0.0, 0.0)),
            Content::Image(image) => {
                let sampling = SamplingOptions::new(FilterMode::Linear, MipmapMode::None);
                canvas.draw_image_rect_with_sampling_options(
                    image,
                    None,
                    bounds,
                    sampling,
                    &Paint::default(),
                );
            }
        }
        for &sublayer in &node.sublayers {
            self.draw(sublayer, canvas);
        }
        if layer.border_width > 0.0 && layer.border_color.a() > 0 {
            let inset = layer.border_width / 2.0;
            let mut border = paint(layer.border_color);
            border
                .set_style(PaintStyle::Stroke)
                .set_stroke_width(layer.border_width);
            canvas.draw_rrect(shape.with_inset((inset, inset)), &border);
        }
        canvas.restore_to_count(saved);
    }

    fn set_content(&mut self, id: LayerId, content: Content) -> bool {
        let Some(node) = self.node_mut(id) else {
            return false;
        };
        node.content = content;
        true
    }

    fn node(&self, id: LayerId) -> Option<&Node> {
        let slot = self.slots.get(id as u32 as usize)?;
        (u64::from(slot.generation) == id >> 32)
            .then_some(slot.node.as_ref())
            .flatten()
    }

    fn node_mut(&mut self, id: LayerId) -> Option<&mut Node> {
        let slot = self.slots.get_mut(id as u32 as usize)?;
        (u64::from(slot.generation) == id >> 32)
            .then_some(slot.node.as_mut())
            .flatten()
    }
}

fn paint(color: Color) -> Paint {
    let mut paint = Paint::default();
    paint.set_color(color).set_anti_alias(true);
    paint
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pixel(image: &Image, x: i32, y: i32) -> Color {
        image.peek_pixels().expect("raster image").get_color((x, y))
    }

    #[test]
    fn draws_layers_with_clips_and_opacity() {
        let mut scene = Scene::new(100.0, 100.0, 2.0);
        let root = scene.root();
        scene.layer_mut(root).unwrap().background_color = Color::WHITE;

        let card = scene.create_layer();
        *scene.layer_mut(card).unwrap() = Layer {
            frame: Rect::from_xywh(10.0, 10.0, 50.0, 50.0),
            background_color: Color::RED,
            masks_to_bounds: true,
            ..Layer::default()
        };
        let overflow = scene.create_layer();
        *scene.layer_mut(overflow).unwrap() = Layer {
            frame: Rect::from_xywh(25.0, 25.0, 50.0, 50.0),
            background_color: Color::BLUE,
            opacity: 0.5,
            ..Layer::default()
        };
        assert!(scene.add_sublayer(root, card));
        assert!(scene.add_sublayer(card, overflow));
        assert!(!scene.add_sublayer(overflow, card), "a cycle");

        let image = scene.render();
        assert_eq!((image.width(), image.height()), (200, 200));
        assert_eq!(pixel(&image, 5, 5), Color::WHITE);
        assert_eq!(pixel(&image, 30, 30), Color::RED);
        // Half blue over red, inside the card.
        let blended = pixel(&image, 100, 100);
        assert!(
            blended.r() > 100 && blended.b() > 100 && blended.g() == 0,
            "{blended:?}"
        );
        // Outside the card, which clips it.
        assert_eq!(pixel(&image, 150, 150), Color::WHITE);
    }

    /// A scene with the fonts from fetch-fonts.sh.
    fn scene_with_fonts() -> Scene {
        let home = std::env::var_os("IRISRUN_HOME").map_or_else(
            || std::path::Path::new(&std::env::var_os("HOME").expect("HOME")).join(".irisrun"),
            Into::into,
        );
        let mut scene = Scene::new(400.0, 300.0, 1.0);
        for name in ["Inter.ttf", "NotoSansSC.ttf"] {
            let path = home.join("fonts").join(name);
            let data = std::fs::read(&path).unwrap_or_else(|error| {
                panic!(
                    "{}: {error}; run crates/render/fetch-fonts.sh",
                    path.display()
                )
            });
            assert!(scene.add_font(&data).is_some(), "{name} is a font");
        }
        scene
    }

    #[test]
    fn shapes_vietnamese_and_cjk_with_fallback_and_weights() {
        let scene = scene_with_fonts();
        let style = TextStyle::default();
        let mut paragraph = scene
            .fonts
            .paragraph("Tiếng Việt: ắ ằ ẳ ẵ ặ ơ ư đ · 中文 · ひらがな", &style);
        paragraph.layout(f32::INFINITY);
        assert_eq!(paragraph.unresolved_glyphs(), Some(0));

        let regular = scene.measure_text("Iris", &style, f32::INFINITY);
        let bold = TextStyle {
            weight: 700,
            ..style.clone()
        };
        assert!(scene.measure_text("Iris", &bold, f32::INFINITY).width > regular.width);
        let wrapped = scene.measure_text("Xin chào thế giới", &style, 60.0);
        assert!(
            wrapped.height >= 2.0 * regular.height,
            "{wrapped:?} vs {regular:?}"
        );
    }

    #[test]
    fn stale_ids_stay_invalid() {
        let mut scene = Scene::new(10.0, 10.0, 1.0);
        let first = scene.create_layer();
        assert!(scene.destroy_layer(first));
        let second = scene.create_layer();
        assert_ne!(first, second, "the slot is reused under a new id");
        assert!(scene.layer(first).is_none());
        assert!(!scene.destroy_layer(first));
        assert!(!scene.destroy_layer(scene.root()));
    }
}
