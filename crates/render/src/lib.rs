//! OpenKit's render core: a retained layer tree in the style of Core
//! Animation's `CALayer`, drawn with Skia on the CPU into frames.
//!
//! OpenKit's SwiftUI and UIKit backends keep a [`Scene`] per window and
//! mirror their views into its layers, from Swift through the C API in
//! `include/irisrun_render.h`. Geometry is in points, as in UIKit; a frame
//! has `scale` pixels per point.

mod animation;
mod ffi;
mod text;

use std::borrow::Cow;
use std::path::Path as FilePath;

use skia_safe::gradient::{self as sk_gradient, shaders as gradient_shaders};
use skia_safe::textlayout::Paragraph;
use skia_safe::{
    AlphaType, BlurStyle, Canvas, ClipOp, Color, Color4f, ColorType, Contains, Data, FilterMode,
    Image, ImageInfo, MaskFilter, Matrix, MipmapMode, Paint, PaintCap, PaintJoin, PaintStyle, Path,
    PathEffect, Point, RRect, Rect, SamplingOptions, Shader, Size, Surface, TileMode, Vector,
    canvas::SaveLayerRec, image_filters, images, jpeg_encoder, png_encoder, surfaces,
};

use animation::Running;
pub use animation::{Animation, Timing, Value};
use text::Fonts;
pub use text::{Caret, FontMetrics, ParagraphStyle, Run, RunStyle, TextAlign, TextMetrics};

/// Identifies a layer in its scene. Ids of destroyed layers are never valid
/// again, so a stale id is an error, not another layer.
pub type LayerId = u64;

/// What a layer looks like. Changes show in the next frame, unless an
/// [`Animation`] of the property is running.
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
    /// Clips the layer and its sublayers to a path in the layer's
    /// coordinates, for drawing and hit-testing alike.
    pub mask: Option<Path>,
    /// Cast by all the layer draws, sublayers included; transparent for
    /// none. `masks_to_bounds` clips it away, as in Core Animation.
    pub shadow_color: Color,
    /// In points, positive y downwards.
    pub shadow_offset: Vector,
    /// The blur, in points.
    pub shadow_radius: f32,
    /// Where an image goes in the bounds.
    pub content_mode: ContentMode,
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
            mask: None,
            shadow_color: Color::TRANSPARENT,
            shadow_offset: Vector::default(),
            shadow_radius: 0.0,
            content_mode: ContentMode::default(),
        }
    }
}

/// How an image fills a layer, as in `UIView.ContentMode`. The modes that
/// don't scale use the image's own size in points.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum ContentMode {
    /// Stretched to the bounds.
    #[default]
    ScaleToFill,
    /// As large as fits whole, centered.
    ScaleAspectFit,
    /// As small as covers the bounds, centered; it spills over unless the
    /// layer masks to bounds.
    ScaleAspectFill,
    Center,
    Top,
    Bottom,
    Left,
    Right,
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
}

/// A path, filled and then stroked, as `CAShapeLayer` draws it.
#[derive(Clone, Debug, PartialEq)]
pub struct Shape {
    /// In the layer's coordinates. Its fill type is the fill rule.
    pub path: Path,
    /// Transparent for no fill.
    pub fill: Color,
    /// Transparent, or a zero line width, for no stroke.
    pub stroke: Color,
    pub line_width: f32,
    pub line_cap: PaintCap,
    pub line_join: PaintJoin,
    pub miter_limit: f32,
    /// Lengths of dashes and gaps, in turn; empty for a solid line.
    pub dashes: Vec<f32>,
    pub dash_phase: f32,
}

impl Default for Shape {
    fn default() -> Self {
        Shape {
            path: Path::default(),
            fill: Color::BLACK,
            stroke: Color::TRANSPARENT,
            line_width: 1.0,
            line_cap: PaintCap::Butt,
            line_join: PaintJoin::Miter,
            miter_limit: 10.0,
            dashes: Vec::new(),
            dash_phase: 0.0,
        }
    }
}

/// Colors blended across a layer's rounded bounds, as `CAGradientLayer`
/// draws them.
#[derive(Clone, Debug, PartialEq)]
pub struct Gradient {
    pub kind: GradientKind,
    pub colors: Vec<Color>,
    /// Where each color sits, from 0 to 1, as many as the colors; empty
    /// spaces them evenly.
    pub locations: Vec<f32>,
}

/// The geometry of a gradient, in the layer's coordinates.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum GradientKind {
    /// Along the line from `start` to `end`.
    Linear { start: Point, end: Point },
    /// In circles around `center`, from `start_radius` out to `end_radius`.
    Radial {
        center: Point,
        start_radius: f32,
        end_radius: f32,
    },
    /// Clockwise around `center`, in radians from the positive x axis.
    Conic {
        center: Point,
        start_angle: f32,
        end_angle: f32,
    },
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
    /// `scale` pixels per point.
    Image {
        image: Image,
        scale: f32,
    },
    Shape {
        path: Path,
        fill: Option<Paint>,
        stroke: Option<Paint>,
    },
    Gradient(Shader),
}

struct Node {
    layer: Layer,
    content: Content,
    parent: Option<LayerId>,
    sublayers: Vec<LayerId>,
    /// At most one per property.
    animations: Vec<Running>,
}

struct Slot {
    generation: u32,
    node: Option<Node>,
}

/// The layers of one window. Not thread-safe: use it from one thread. The
/// frames it renders are images any thread may encode.
pub struct Scene {
    slots: Vec<Slot>,
    free: Vec<u32>,
    root: LayerId,
    size: Size,
    scale: f32,
    fonts: Fonts,
    surface: Option<Surface>,
    /// In seconds; animations run on it.
    time: f64,
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
            time: 0.0,
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

    /// Like [`Scene::add_font`], but maps the file instead of reading it, so
    /// a large CJK font takes memory only for the glyphs drawn.
    pub fn add_font_file(&mut self, path: impl AsRef<FilePath>) -> Option<String> {
        self.fonts.add_file(path.as_ref())
    }

    /// The metrics of the first font added, at a size and weight.
    pub fn font_metrics(&self, size: f32, weight: u16) -> Option<FontMetrics> {
        self.fonts.metrics(size, weight)
    }

    /// A new layer, not in the tree until added to a parent.
    pub fn create_layer(&mut self) -> LayerId {
        let node = Node {
            layer: Layer::default(),
            content: Content::None,
            parent: None,
            sublayers: Vec::new(),
            animations: Vec::new(),
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

    /// Text in runs of styles, laid out to the layer's width.
    pub fn set_text(
        &mut self,
        id: LayerId,
        text: &str,
        runs: &[Run],
        style: &ParagraphStyle,
    ) -> bool {
        let paragraph = self.fonts.paragraph(text, runs, style);
        self.set_content(
            id,
            Content::Text {
                paragraph,
                width: f32::NAN,
            },
        )
    }

    /// Where text goes when its lines may be up to `max_width` wide. Layout
    /// calls this to size text views.
    pub fn measure_text(
        &self,
        text: &str,
        runs: &[Run],
        style: &ParagraphStyle,
        max_width: f32,
    ) -> TextMetrics {
        TextMetrics::of(&self.layout_text(text, runs, style, max_width))
    }

    /// Where the caret goes before byte `offset` of text that lays out as
    /// `measure_text` lays it out, or after the last character.
    pub fn text_caret(
        &self,
        text: &str,
        runs: &[Run],
        style: &ParagraphStyle,
        max_width: f32,
        offset: usize,
    ) -> Caret {
        let offset = text::floor_char_boundary(text, offset);
        // Empty text, and the empty line after a final newline, have no
        // glyph to put the caret by: a zero-width space in the style of the
        // run that ends the text gives them one.
        if offset == text.len() && (text.is_empty() || text.ends_with('\n')) {
            let padded = format!("{text}\u{200B}");
            let runs: Vec<Run> = runs
                .iter()
                .map(|run| match run.range.end >= text.len() {
                    true => Run {
                        range: run.range.start..padded.len(),
                        ..run.clone()
                    },
                    false => run.clone(),
                })
                .collect();
            return self.text_caret(&padded, &runs, style, max_width, offset);
        }
        let paragraph = self.layout_text(text, runs, style, max_width);
        Caret::of(&paragraph, text, offset).unwrap_or(Caret {
            x: 0.0,
            y: 0.0,
            height: paragraph.height(),
        })
    }

    /// The byte offset of the character boundary nearest to a point in text
    /// that lays out as `measure_text` lays it out, for placing the caret
    /// where the text is touched.
    pub fn text_offset_at(
        &self,
        text: &str,
        runs: &[Run],
        style: &ParagraphStyle,
        max_width: f32,
        point: Point,
    ) -> usize {
        text::offset_at(&self.layout_text(text, runs, style, max_width), text, point)
    }

    fn layout_text(
        &self,
        text: &str,
        runs: &[Run],
        style: &ParagraphStyle,
        max_width: f32,
    ) -> Paragraph {
        // SkParagraph forms no lines when it must center or right-align them
        // in unbounded width. Lines then start at 0 anyway, so lay out leading.
        let leading;
        let style = if max_width.is_finite() || style.align == TextAlign::Leading {
            style
        } else {
            leading = ParagraphStyle {
                align: TextAlign::Leading,
                ..style.clone()
            };
            &leading
        };
        let mut paragraph = self.fonts.paragraph(text, runs, style);
        paragraph.layout(max_width);
        paragraph
    }

    /// The pixel size of a PNG, JPEG, WebP, GIF or BMP image, from its
    /// header, for layout before anything is drawn.
    pub fn image_size(encoded: &[u8]) -> Option<(i32, i32)> {
        let image = Image::from_encoded(Data::new_copy(encoded))?;
        Some((image.width(), image.height()))
    }

    /// Shows a PNG, JPEG, WebP, GIF or BMP image that has `scale` pixels per
    /// point. Fails if it cannot be decoded.
    pub fn set_image(&mut self, id: LayerId, encoded: &[u8], scale: f32) -> bool {
        match Image::from_encoded(Data::new_copy(encoded)) {
            Some(image) => self.set_content(
                id,
                Content::Image {
                    image,
                    scale: scale_or_one(scale),
                },
            ),
            None => false,
        }
    }

    /// Shows RGBA pixels, 8 bits a channel, `row_bytes` apart, with `scale`
    /// pixels per point. Fails if `rgba` is too short.
    pub fn set_image_pixels(
        &mut self,
        id: LayerId,
        (width, height): (i32, i32),
        rgba: &[u8],
        row_bytes: usize,
        premultiplied: bool,
        scale: f32,
    ) -> bool {
        let alpha = if premultiplied {
            AlphaType::Premul
        } else {
            AlphaType::Unpremul
        };
        let info = ImageInfo::new((width, height), ColorType::RGBA8888, alpha, None);
        let needed = row_bytes.checked_mul(height.max(0) as usize);
        if row_bytes < info.min_row_bytes() || needed.is_none_or(|needed| rgba.len() < needed) {
            return false;
        }
        match images::raster_from_data(&info, Data::new_copy(rgba), row_bytes) {
            Some(image) => self.set_content(
                id,
                Content::Image {
                    image,
                    scale: scale_or_one(scale),
                },
            ),
            None => false,
        }
    }

    pub fn set_shape(&mut self, id: LayerId, shape: &Shape) -> bool {
        let fill = (shape.fill.a() > 0).then(|| paint(shape.fill));
        let stroke = (shape.stroke.a() > 0 && shape.line_width > 0.0).then(|| {
            let mut stroke = paint(shape.stroke);
            stroke
                .set_style(PaintStyle::Stroke)
                .set_stroke_width(shape.line_width)
                .set_stroke_cap(shape.line_cap)
                .set_stroke_join(shape.line_join)
                .set_stroke_miter(shape.miter_limit);
            // Skia wants pairs; an odd list repeats, as in Core Graphics.
            let mut dashes = shape.dashes.clone();
            if dashes.len() % 2 == 1 {
                dashes.extend_from_within(..);
            }
            if dashes.iter().all(|&length| length >= 0.0) && dashes.iter().sum::<f32>() > 0.0 {
                stroke.set_path_effect(PathEffect::dash(&dashes, shape.dash_phase));
            }
            stroke
        });
        let path = shape.path.clone();
        self.set_content(id, Content::Shape { path, fill, stroke })
    }

    /// Fails without two colors, or with locations that don't match them.
    pub fn set_gradient(&mut self, id: LayerId, gradient: &Gradient) -> bool {
        let colors = gradient.colors.as_slice();
        let locations = match gradient.locations.len() {
            0 => None,
            n if n == colors.len() => Some(gradient.locations.as_slice()),
            _ => return false,
        };
        if colors.len() < 2 {
            return false;
        }
        let colors: Vec<Color4f> = colors.iter().map(|&color| color.into()).collect();
        let sk = sk_gradient::Gradient::new(
            sk_gradient::Colors::new(&colors, locations, TileMode::Clamp, None),
            sk_gradient::Interpolation::default(),
        );
        let shader = match gradient.kind {
            GradientKind::Linear { start, end } => {
                gradient_shaders::linear_gradient((start, end), &sk, None)
            }
            GradientKind::Radial {
                center,
                start_radius,
                end_radius,
            } => gradient_shaders::two_point_conical_gradient(
                (center, start_radius.max(0.0)),
                (center, end_radius.max(0.0)),
                &sk,
                None,
            ),
            GradientKind::Conic {
                center,
                start_angle,
                end_angle,
            } => gradient_shaders::sweep_gradient(
                center,
                (start_angle.to_degrees(), end_angle.to_degrees()),
                &sk,
                None,
            ),
        };
        match shader {
            Some(shader) => self.set_content(id, Content::Gradient(shader)),
            None => false,
        }
    }

    pub fn clear_content(&mut self, id: LayerId) -> bool {
        self.set_content(id, Content::None)
    }

    /// The scene's clock, in seconds. Frames show animations as they are at
    /// this time; the caller moves it forward, so tests can use a virtual one.
    pub fn time(&self) -> f64 {
        self.time
    }

    pub fn set_time(&mut self, time: f64) {
        self.time = time;
    }

    /// Starts an animation `delay` seconds from the scene's time, replacing
    /// one of the same property. Fails if `from` and `to` are different
    /// properties.
    pub fn add_animation(&mut self, id: LayerId, animation: Animation) -> bool {
        let begin = self.time + animation.delay.max(0.0);
        if !animation.from.same_property(animation.to) {
            return false;
        }
        let Some(node) = self.node_mut(id) else {
            return false;
        };
        node.animations
            .retain(|running| !running.animation.from.same_property(animation.from));
        node.animations.push(Running { animation, begin });
        true
    }

    pub fn remove_animations(&mut self, id: LayerId) -> bool {
        let Some(node) = self.node_mut(id) else {
            return false;
        };
        node.animations.clear();
        true
    }

    /// Whether an animation is still to run, so frames still change.
    pub fn is_animating(&self) -> bool {
        self.slots
            .iter()
            .filter_map(|slot| slot.node.as_ref())
            .flat_map(|node| &node.animations)
            .any(|running| !running.finished(self.time))
    }

    /// The front-most layer at `point`, in scene coordinates, as
    /// `CALayer.hitTest` finds it: hidden layers and what their parent
    /// masks away are skipped, and animations are not, since this uses the
    /// layers' own values.
    pub fn hit_test(&self, point: impl Into<Point>) -> Option<LayerId> {
        self.hit(self.root, point.into())
    }

    fn hit(&self, id: LayerId, point: Point) -> Option<LayerId> {
        let node = self.node(id)?;
        let layer = &node.layer;
        if layer.hidden {
            return None;
        }
        let local = local_matrix(layer).invert()?.map_point(point);
        let inside = Rect::from_size(layer.frame.size()).contains(local)
            && layer.mask.as_ref().is_none_or(|mask| mask.contains(local));
        if !inside && (layer.masks_to_bounds || layer.mask.is_some()) {
            return None;
        }
        node.sublayers
            .iter()
            .rev()
            .find_map(|&sublayer| self.hit(sublayer, local))
            .or(inside.then_some(id))
    }

    /// Draws the tree into a frame of `size × scale` pixels.
    pub fn render(&mut self) -> Image {
        let time = self.time;
        for slot in &mut self.slots {
            let Some(node) = &mut slot.node else { continue };
            node.animations.retain(|running| !running.finished(time));
            if let Content::Text { paragraph, width } = &mut node.content
                && *width != node.layer.frame.width()
            {
                paragraph.layout(node.layer.frame.width());
                *width = node.layer.frame.width();
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
        encode(&self.render(), format, quality)
    }

    fn draw(&self, id: LayerId, canvas: &Canvas) {
        let Some(node) = self.node(id) else { return };
        let layer = self.shown(node);
        if layer.hidden || layer.opacity <= 0.0 {
            return;
        }
        let saved = canvas.save();
        canvas.concat(&local_matrix(&layer));
        let size = layer.frame.size();
        let bounds = Rect::from_size(size);
        let shape = RRect::new_rect_xy(bounds, layer.corner_radius, layer.corner_radius);

        let shadow = layer.shadow_color.a() > 0 && !layer.masks_to_bounds;
        // Offscreen groups as large as what the layer draws, not the frame.
        let drawn = if shadow || layer.opacity < 1.0 {
            self.drawn_bounds(node, &layer)
        } else {
            bounds
        };
        // ponytail: sigma as half of Core Animation's blur radius, by eye;
        // compare with simulator frames once there are some.
        let sigma = layer.shadow_radius.max(0.0) / 2.0;
        // The shadow of an opaque rounded rectangle that nothing sticks out of
        // is the rectangle's own, blurred: far cheaper than blurring a group.
        let plain_shadow =
            shadow && layer.background_color.a() == 255 && layer.mask.is_none() && drawn == bounds;
        if shadow && !plain_shadow {
            let mut group = Paint::default();
            group
                .set_alpha_f(layer.opacity)
                .set_image_filter(image_filters::drop_shadow(
                    layer.shadow_offset,
                    (sigma, sigma),
                    layer.shadow_color,
                    None,
                    None,
                    None,
                ));
            canvas.save_layer(&SaveLayerRec::default().bounds(&drawn).paint(&group));
        } else if layer.opacity < 1.0 {
            canvas.save_layer_alpha_f(drawn, layer.opacity);
        }
        if plain_shadow {
            let mut blurred = paint(layer.shadow_color);
            // In points, as the group's blur, not device pixels.
            blurred.set_mask_filter(MaskFilter::blur(BlurStyle::Normal, sigma, true));
            canvas.draw_rrect(shape.with_offset(layer.shadow_offset), &blurred);
        }
        if let Some(mask) = &layer.mask {
            canvas.clip_path(mask, ClipOp::Intersect, true);
        }

        if layer.background_color.a() > 0 {
            canvas.draw_rrect(shape, &paint(layer.background_color));
        }
        if layer.masks_to_bounds {
            canvas.clip_rrect(shape, ClipOp::Intersect, true);
        }
        match &node.content {
            Content::None => {}
            Content::Text { paragraph, .. } => paragraph.paint(canvas, (0.0, 0.0)),
            Content::Image { image, scale } => {
                let sampling = SamplingOptions::new(FilterMode::Linear, MipmapMode::None);
                canvas.draw_image_rect_with_sampling_options(
                    image,
                    None,
                    image_rect(layer.content_mode, size, natural_size(image, *scale)),
                    sampling,
                    &Paint::default(),
                );
            }
            Content::Shape { path, fill, stroke } => {
                for paint in [fill, stroke].into_iter().flatten() {
                    canvas.draw_path(path, paint);
                }
            }
            Content::Gradient(shader) => {
                let mut gradient = Paint::default();
                gradient.set_shader(shader.clone()).set_anti_alias(true);
                canvas.draw_rrect(shape, &gradient);
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

    /// What a layer, its content and its sublayers draw on, shadows
    /// included, in its own coordinates.
    fn drawn_bounds(&self, node: &Node, layer: &Layer) -> Rect {
        let size = layer.frame.size();
        let mut drawn = Rect::from_size(size);
        match &node.content {
            Content::Text { paragraph, .. } => {
                drawn.join(Rect::from_wh(paragraph.longest_line(), paragraph.height()))
            }
            Content::Image { image, scale } => drawn.join(image_rect(
                layer.content_mode,
                size,
                natural_size(image, *scale),
            )),
            Content::Shape { path, stroke, .. } => {
                let width = stroke.as_ref().map_or(0.0, Paint::stroke_width);
                // Generous for miter joins, which reach past half the width.
                drawn.join(
                    path.compute_tight_bounds()
                        .with_outset((width * 2.0, width * 2.0)),
                );
            }
            Content::None | Content::Gradient(_) => {}
        }
        if !layer.masks_to_bounds {
            for &id in &node.sublayers {
                let Some(child) = self.node(id) else { continue };
                let shown = self.shown(child);
                if shown.hidden || shown.opacity <= 0.0 {
                    continue;
                }
                let mut child_drawn = self.drawn_bounds(child, &shown);
                if shown.shadow_color.a() > 0 && !shown.masks_to_bounds {
                    // Three sigmas hold all of a Gaussian blur that shows.
                    let blur = 1.5 * shown.shadow_radius.max(0.0);
                    child_drawn.join(
                        child_drawn
                            .with_offset(shown.shadow_offset)
                            .with_outset((blur, blur)),
                    );
                }
                drawn.join(local_matrix(&shown).map_rect(child_drawn).0);
            }
        }
        if let Some(mask) = &layer.mask
            && !drawn.intersect(mask.bounds())
        {
            return Rect::new_empty();
        }
        drawn
    }

    /// The layer as its animations show it at the scene's time.
    fn shown<'a>(&self, node: &'a Node) -> Cow<'a, Layer> {
        if node.animations.is_empty() {
            return Cow::Borrowed(&node.layer);
        }
        let mut layer = node.layer.clone();
        for running in &node.animations {
            if let Some(value) = running.value(self.time) {
                value.apply(&mut layer);
            }
        }
        Cow::Owned(layer)
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

/// Encodes a frame from [`Scene::render`], on any thread. `quality` (0–100)
/// applies to JPEG.
pub fn encode(frame: &Image, format: ImageFormat, quality: u8) -> Option<Vec<u8>> {
    let pixmap = frame.peek_pixels()?;
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

/// From a layer's coordinates to its parent's.
fn local_matrix(layer: &Layer) -> Matrix {
    let mut matrix = Matrix::translate((layer.frame.left, layer.frame.top));
    if layer.transform != IDENTITY {
        let center = (layer.frame.width() / 2.0, layer.frame.height() / 2.0);
        matrix
            .pre_translate(center)
            .pre_concat(&Matrix::from_affine(&layer.transform))
            .pre_translate((-center.0, -center.1));
    }
    matrix
}

/// Where an image `natural` points large goes in `bounds`.
fn image_rect(mode: ContentMode, bounds: Size, natural: Size) -> Rect {
    let fit = |scale: f32| {
        let size = Size::new(natural.width * scale, natural.height * scale);
        Rect::from_xywh(
            (bounds.width - size.width) / 2.0,
            (bounds.height - size.height) / 2.0,
            size.width,
            size.height,
        )
    };
    let (sx, sy) = (bounds.width / natural.width, bounds.height / natural.height);
    // Fractions of the spare room to the left and above.
    let (x, y) = match mode {
        ContentMode::ScaleToFill => return Rect::from_size(bounds),
        ContentMode::ScaleAspectFit => return fit(sx.min(sy)),
        ContentMode::ScaleAspectFill => return fit(sx.max(sy)),
        ContentMode::Center => (0.5, 0.5),
        ContentMode::Top => (0.5, 0.0),
        ContentMode::Bottom => (0.5, 1.0),
        ContentMode::Left => (0.0, 0.5),
        ContentMode::Right => (1.0, 0.5),
        ContentMode::TopLeft => (0.0, 0.0),
        ContentMode::TopRight => (1.0, 0.0),
        ContentMode::BottomLeft => (0.0, 1.0),
        ContentMode::BottomRight => (1.0, 1.0),
    };
    Rect::from_xywh(
        (bounds.width - natural.width) * x,
        (bounds.height - natural.height) * y,
        natural.width,
        natural.height,
    )
}

/// An image's size in points.
fn natural_size(image: &Image, scale: f32) -> Size {
    Size::new(image.width() as f32 / scale, image.height() as f32 / scale)
}

fn scale_or_one(scale: f32) -> f32 {
    if scale > 0.0 { scale } else { 1.0 }
}

fn paint(color: Color) -> Paint {
    let mut paint = Paint::default();
    paint.set_color(color).set_anti_alias(true);
    paint
}

#[cfg(test)]
mod tests;
