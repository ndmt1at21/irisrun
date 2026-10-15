//! Text, laid out by SkParagraph with the fonts the scene was given.

use skia_safe::font_arguments::VariationPosition;
use skia_safe::font_arguments::variation_position::Coordinate;
use skia_safe::font_style::{Slant, Weight, Width};
use skia_safe::textlayout::{
    FontCollection, Paragraph, ParagraphBuilder, ParagraphStyle, TextAlign as SkTextAlign,
    TextStyle as SkTextStyle, TypefaceFontProvider,
};
use skia_safe::{Color, Data, FontArguments, FontMgr, FontStyle, FourByteTag};

const WEIGHT_AXIS: FourByteTag = FourByteTag::from_chars('w', 'g', 'h', 't');

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum TextAlign {
    #[default]
    Leading,
    Center,
    Trailing,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TextStyle {
    /// In points.
    pub size: f32,
    /// From 100 (thin) to 900 (black); 400 is regular.
    pub weight: u16,
    pub color: Color,
    pub align: TextAlign,
    /// Lines past the limit are cut, the last one with an ellipsis. 0 means
    /// no limit.
    pub max_lines: usize,
}

impl Default for TextStyle {
    fn default() -> Self {
        TextStyle {
            size: 17.0, // iOS body text
            weight: 400,
            color: Color::BLACK,
            align: TextAlign::Leading,
            max_lines: 0,
        }
    }
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
        let typeface = self.loader.new_from_data(Data::new_copy(data), None)?;
        let family = typeface.family_name();
        self.provider.register_typeface(typeface, None);
        if !self.families.contains(&family) {
            self.families.push(family.clone());
        }
        self.collection.clear_caches();
        Some(family)
    }

    /// Characters missing from the first family come from the next one that
    /// has them, so Latin text can use one font and CJK another.
    pub fn paragraph(&self, text: &str, style: &TextStyle) -> Paragraph {
        let weight = style.weight.clamp(100, 900);
        // Variable fonts get their weight from the axis; static fonts by style.
        let coordinates = [Coordinate {
            axis: WEIGHT_AXIS,
            value: weight.into(),
        }];
        let arguments = FontArguments::new().set_variation_design_position(VariationPosition {
            coordinates: &coordinates,
        });
        let mut text_style = SkTextStyle::new();
        text_style
            .set_font_families(&self.families)
            .set_font_size(style.size)
            .set_color(style.color)
            .set_font_style(FontStyle::new(
                Weight::from(i32::from(weight)),
                Width::NORMAL,
                Slant::Upright,
            ))
            .set_font_arguments(&arguments);

        let mut paragraph_style = ParagraphStyle::new();
        paragraph_style
            .set_text_style(&text_style)
            .set_text_align(match style.align {
                TextAlign::Leading => SkTextAlign::Start,
                TextAlign::Center => SkTextAlign::Center,
                TextAlign::Trailing => SkTextAlign::End,
            });
        if style.max_lines > 0 {
            paragraph_style
                .set_max_lines(style.max_lines)
                .set_ellipsis("…");
        }

        let mut builder = ParagraphBuilder::new(&paragraph_style, self.collection.clone());
        builder.push_style(&text_style).add_text(text);
        builder.build()
    }
}
