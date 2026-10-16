//! Text, laid out by SkParagraph with the fonts the scene was given.

use std::ops::Range;
use std::path::Path;

use skia_safe::font_arguments::VariationPosition;
use skia_safe::font_arguments::variation_position::Coordinate;
use skia_safe::font_style::{Slant, Weight, Width};
use skia_safe::textlayout::{
    FontCollection, Paragraph, ParagraphBuilder, ParagraphStyle as SkParagraphStyle,
    RectHeightStyle, RectWidthStyle, TextAlign as SkTextAlign, TextDecoration, TextHeightBehavior,
    TextStyle as SkTextStyle, TypefaceFontProvider,
};
use skia_safe::{
    Color, Data, Font, FontArguments, FontMgr, FontStyle, FourByteTag, Paint, Point, Typeface,
};

const WEIGHT_AXIS: FourByteTag = FourByteTag::from_chars('w', 'g', 'h', 't');

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum TextAlign {
    #[default]
    Leading,
    Center,
    Trailing,
}

/// How a run of text looks.
#[derive(Clone, Debug, PartialEq)]
pub struct RunStyle {
    /// In points.
    pub size: f32,
    /// From 100 (thin) to 900 (black); 400 is regular.
    pub weight: u16,
    pub color: Color,
    pub italic: bool,
    pub underline: bool,
    pub strikethrough: bool,
    /// Space added after each character, in points.
    pub letter_spacing: f32,
    /// How far the run sits above the baseline, in points.
    pub baseline_offset: f32,
    /// Fills the run's line boxes; transparent for none.
    pub background: Color,
}

impl Default for RunStyle {
    fn default() -> Self {
        RunStyle {
            size: 17.0, // iOS body text
            weight: 400,
            color: Color::BLACK,
            italic: false,
            underline: false,
            strikethrough: false,
            letter_spacing: 0.0,
            baseline_offset: 0.0,
            background: Color::TRANSPARENT,
        }
    }
}

/// The bytes `range` of a text, styled by `style`.
#[derive(Clone, Debug, PartialEq)]
pub struct Run {
    pub range: Range<usize>,
    pub style: RunStyle,
}

/// How a paragraph breaks into lines.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ParagraphStyle {
    pub align: TextAlign,
    /// Lines past the limit are cut, the last one with an ellipsis. 0 means
    /// no limit.
    pub max_lines: usize,
    /// Space added between lines, in points.
    pub line_spacing: f32,
}

/// Where text sits once laid out. Distances are in points from the top.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TextMetrics {
    pub width: f32,
    pub height: f32,
    pub first_baseline: f32,
    pub last_baseline: f32,
    pub line_count: usize,
    /// Lines were cut by `max_lines`.
    pub truncated: bool,
}

impl TextMetrics {
    pub(crate) fn of(paragraph: &Paragraph) -> TextMetrics {
        // Where glyphs are drawn; alphabetic_baseline() leaves out part of
        // the line's leading.
        let lines = paragraph.get_line_metrics();
        let baseline = |line: Option<&skia_safe::textlayout::LineMetrics>| {
            line.map_or(paragraph.alphabetic_baseline(), |line| line.baseline as f32)
        };
        TextMetrics {
            width: paragraph.longest_line().ceil(),
            height: paragraph.height().ceil(),
            first_baseline: baseline(lines.first()),
            last_baseline: baseline(lines.last()),
            line_count: paragraph.line_number(),
            truncated: paragraph.did_exceed_max_lines(),
        }
    }
}

/// Where the caret goes in laid-out text, in points from its top-left
/// corner: a vertical bar as tall as the glyphs of its line.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Caret {
    pub x: f32,
    pub y: f32,
    pub height: f32,
}

impl Caret {
    /// Before the character at byte `offset` of `text`, or after the last
    /// one, on the line that holds that character. At a soft line break
    /// that is the start of the next line, as in UIKit.
    pub(crate) fn of(paragraph: &Paragraph, text: &str, offset: usize) -> Option<Caret> {
        let offset = floor_char_boundary(text, offset);
        // SkParagraph counts in UTF-16.
        let at = text[..offset].encode_utf16().count();
        let lines = paragraph.get_line_metrics();
        let line = lines.iter().rev().find(|line| line.start_index <= at)?;
        let mut x = line.left as f32;
        if at > line.start_index {
            let before = text[..offset]
                .chars()
                .next_back()
                .map_or(0, char::len_utf16);
            let boxes = paragraph.get_rects_for_range(
                at - before..at,
                RectHeightStyle::Tight,
                RectWidthStyle::Tight,
            );
            x = boxes
                .last()
                .map_or((line.left + line.width) as f32, |b| b.rect.right);
        }
        Some(Caret {
            x,
            y: (line.baseline - line.ascent) as f32,
            height: (line.ascent + line.descent) as f32,
        })
    }
}

/// The byte offset of the character boundary nearest to `point` in
/// laid-out text, for placing the caret where the text is touched.
pub(crate) fn offset_at(paragraph: &Paragraph, text: &str, point: Point) -> usize {
    let position = paragraph.get_glyph_position_at_coordinate(point).position;
    let mut units = usize::try_from(position).unwrap_or(0);
    for (offset, char) in text.char_indices() {
        if units < char.len_utf16() {
            return offset;
        }
        units -= char.len_utf16();
    }
    text.len()
}

/// The vertical metrics of a font, in points, signed as in `UIFont`: the
/// ascender is above the baseline and positive, the descender below it and
/// negative.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FontMetrics {
    pub ascender: f32,
    pub descender: f32,
    pub leading: f32,
    pub cap_height: f32,
    pub x_height: f32,
}

/// The fonts of a scene. Only these are used, never the machine's, so a
/// frame looks the same everywhere.
pub(crate) struct Fonts {
    /// Makes typefaces from font files.
    loader: FontMgr,
    provider: TypefaceFontProvider,
    collection: FontCollection,
    /// In the order they were added, which is the fallback order.
    families: Vec<String>,
}

impl Fonts {
    pub fn new() -> Fonts {
        let provider = TypefaceFontProvider::new();
        let mut collection = FontCollection::new();
        collection.set_asset_font_manager(Some(provider.clone().into()));
        Fonts {
            loader: FontMgr::new(),
            provider,
            collection,
            families: Vec::new(),
        }
    }

    /// Adds a TrueType or OpenType font and returns its family name.
    pub fn add(&mut self, data: &[u8]) -> Option<String> {
        self.register(Data::new_copy(data))
    }

    /// Adds a font file, mapped rather than read, so only the glyphs drawn
    /// take memory.
    pub fn add_file(&mut self, path: &Path) -> Option<String> {
        self.register(Data::from_filename(path)?)
    }

    fn register(&mut self, data: Data) -> Option<String> {
        let typeface = self.loader.new_from_data(data, None)?;
        let family = typeface.family_name();
        self.provider.register_typeface(typeface, None);
        if !self.families.contains(&family) {
            self.families.push(family.clone());
        }
        self.collection.clear_caches();
        Some(family)
    }

    /// Characters missing from the first family come from the next one that
    /// has them, so Latin text can use one font and CJK another. Bytes no run
    /// covers get the default style.
    pub fn paragraph(&self, text: &str, runs: &[Run], style: &ParagraphStyle) -> Paragraph {
        let mut paragraph_style = SkParagraphStyle::new();
        paragraph_style
            .set_text_style(&self.text_style(&RunStyle::default(), style.line_spacing))
            .set_text_align(match style.align {
                TextAlign::Leading => SkTextAlign::Start,
                TextAlign::Center => SkTextAlign::Center,
                TextAlign::Trailing => SkTextAlign::End,
            });
        if style.line_spacing != 0.0 {
            // Spacing goes between lines, not above the first or below the last.
            paragraph_style.set_text_height_behavior(TextHeightBehavior::DisableAll);
        }
        if style.max_lines > 0 {
            paragraph_style
                .set_max_lines(style.max_lines)
                .set_ellipsis("…");
        }

        let mut builder = ParagraphBuilder::new(&paragraph_style, self.collection.clone());
        let mut runs: Vec<&Run> = runs.iter().collect();
        runs.sort_by_key(|run| run.range.start);
        let mut at = 0;
        for run in runs {
            let start = floor_char_boundary(text, run.range.start.max(at));
            let end = floor_char_boundary(text, run.range.end);
            if start > at {
                builder.add_text(&text[at..start]);
            }
            if end > start {
                builder
                    .push_style(&self.text_style(&run.style, style.line_spacing))
                    .add_text(&text[start..end])
                    .pop();
                at = end;
            }
        }
        if at < text.len() {
            builder.add_text(&text[at..]);
        }
        builder.build()
    }

    /// The metrics of the first font, the one most text is set in.
    pub fn metrics(&self, size: f32, weight: u16) -> Option<FontMetrics> {
        let (_, metrics) = Font::from_typeface(self.typeface(weight)?, size).metrics();
        Some(FontMetrics {
            ascender: -metrics.ascent,
            descender: -metrics.descent,
            leading: metrics.leading,
            cap_height: metrics.cap_height,
            x_height: metrics.x_height,
        })
    }

    fn typeface(&self, weight: u16) -> Option<Typeface> {
        let weight = weight.clamp(100, 900);
        let style = FontStyle::new(
            Weight::from(i32::from(weight)),
            Width::NORMAL,
            Slant::Upright,
        );
        let typeface = self
            .provider
            .match_family_style(self.families.first()?, style)?;
        let coordinates = weight_axis(weight);
        Some(
            typeface
                .clone_with_arguments(&FontArguments::new().set_variation_design_position(
                    VariationPosition {
                        coordinates: &coordinates,
                    },
                ))
                .unwrap_or(typeface),
        )
    }

    fn text_style(&self, run: &RunStyle, line_spacing: f32) -> SkTextStyle {
        let weight = run.weight.clamp(100, 900);
        // Variable fonts get their weight from the axis; static fonts by style.
        let coordinates = weight_axis(weight);
        let arguments = FontArguments::new().set_variation_design_position(VariationPosition {
            coordinates: &coordinates,
        });
        let mut style = SkTextStyle::new();
        // Skia reads an empty list through a null pointer.
        if !self.families.is_empty() {
            style.set_font_families(&self.families);
        }
        style
            .set_font_size(run.size)
            .set_color(run.color)
            .set_font_style(FontStyle::new(
                Weight::from(i32::from(weight)),
                Width::NORMAL,
                if run.italic {
                    Slant::Italic
                } else {
                    Slant::Upright
                },
            ))
            .set_font_arguments(&arguments);
        style
            .set_letter_spacing(run.letter_spacing)
            .set_baseline_shift(-run.baseline_offset);
        let mut decoration = TextDecoration::NO_DECORATION;
        decoration.set(TextDecoration::UNDERLINE, run.underline);
        decoration.set(TextDecoration::LINE_THROUGH, run.strikethrough);
        style.set_decoration_type(decoration);
        style.set_decoration_color(run.color);
        if run.background.a() > 0 {
            let mut background = Paint::default();
            background.set_color(run.background);
            style.set_background_paint(&background);
        }
        if line_spacing != 0.0
            && let Some(metrics) = self.metrics(run.size, weight)
            && run.size > 0.0
        {
            // A line height of the font's own plus the spacing, split evenly
            // above and below each line.
            let natural = metrics.ascender - metrics.descender + metrics.leading;
            style
                .set_height((natural + line_spacing) / run.size)
                .set_height_override(true)
                .set_half_leading(true);
        }
        style
    }
}

fn weight_axis(weight: u16) -> [Coordinate; 1] {
    [Coordinate {
        axis: WEIGHT_AXIS,
        value: weight.into(),
    }]
}

/// The largest char boundary at or before `index`, which callers on the
/// other side of the C API may get wrong.
pub(crate) fn floor_char_boundary(text: &str, index: usize) -> usize {
    let mut index = index.min(text.len());
    while !text.is_char_boundary(index) {
        index -= 1;
    }
    index
}
