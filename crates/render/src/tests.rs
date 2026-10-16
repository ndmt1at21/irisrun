use std::path::PathBuf;

use skia_safe::PathBuilder;

use super::*;

fn pixel(image: &Image, x: i32, y: i32) -> Color {
    image.peek_pixels().expect("raster image").get_color((x, y))
}

/// A white scene with one layer in it.
fn scene_with_layer(layer: Layer) -> (Scene, LayerId) {
    let mut scene = Scene::new(100.0, 100.0, 1.0);
    let root = scene.root();
    scene.layer_mut(root).unwrap().background_color = Color::WHITE;
    let id = scene.create_layer();
    *scene.layer_mut(id).unwrap() = layer;
    assert!(scene.add_sublayer(root, id));
    (scene, id)
}

fn fonts_dir() -> PathBuf {
    let home = std::env::var_os("IRISRUN_HOME").map_or_else(
        || PathBuf::from(std::env::var_os("HOME").expect("HOME")).join(".irisrun"),
        Into::into,
    );
    home.join("fonts")
}

/// A scene with the fonts from fetch-fonts.sh.
fn scene_with_fonts() -> Scene {
    let mut scene = Scene::new(400.0, 300.0, 1.0);
    for name in ["Inter.ttf", "InterItalic.ttf", "NotoSansSC.ttf"] {
        let path = fonts_dir().join(name);
        assert!(
            scene.add_font_file(&path).is_some(),
            "{}: missing or not a font; run crates/render/fetch-fonts.sh",
            path.display()
        );
    }
    scene
}

fn run(text: &str, style: RunStyle) -> Vec<Run> {
    vec![Run {
        range: 0..text.len(),
        style,
    }]
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

#[test]
fn shapes_vietnamese_and_cjk_with_fallback_and_weights() {
    let scene = scene_with_fonts();
    let text = "Tiếng Việt: ắ ằ ẳ ẵ ặ ơ ư đ · 中文 · ひらがな";
    let mut paragraph = scene.fonts.paragraph(
        text,
        &run(text, RunStyle::default()),
        &ParagraphStyle::default(),
    );
    paragraph.layout(f32::INFINITY);
    assert_eq!(paragraph.unresolved_glyphs(), Some(0));

    let measure = |style: RunStyle, width: f32| {
        scene.measure_text(
            "Iris",
            &run("Iris", style),
            &ParagraphStyle::default(),
            width,
        )
    };
    let regular = measure(RunStyle::default(), f32::INFINITY);
    let bold = RunStyle {
        weight: 700,
        ..RunStyle::default()
    };
    assert!(measure(bold, f32::INFINITY).width > regular.width);
    let width = |style: RunStyle| {
        let text = "The quick brown fox";
        let mut paragraph =
            scene
                .fonts
                .paragraph(text, &run(text, style), &ParagraphStyle::default());
        paragraph.layout(f32::INFINITY);
        paragraph.longest_line()
    };
    let italic = RunStyle {
        italic: true,
        ..RunStyle::default()
    };
    assert_ne!(
        width(italic),
        width(RunStyle::default()),
        "Inter Italic has its own advances"
    );

    let text = "Xin chào thế giới";
    let wrapped = scene.measure_text(
        text,
        &run(text, RunStyle::default()),
        &ParagraphStyle::default(),
        60.0,
    );
    assert!(wrapped.line_count >= 2, "{wrapped:?}");
    assert!(
        wrapped.height >= 2.0 * regular.height,
        "{wrapped:?} vs {regular:?}"
    );
}

#[test]
fn measures_baselines_lines_and_truncation() {
    let scene = scene_with_fonts();
    let body = RunStyle::default();
    let one = scene.measure_text(
        "Iris",
        &run("Iris", body.clone()),
        &ParagraphStyle::default(),
        f32::INFINITY,
    );
    assert_eq!(one.line_count, 1);
    assert!(!one.truncated);
    assert_eq!(one.first_baseline, one.last_baseline);
    // Inter's ascender is 0.97 em; the baseline sits that far down.
    let metrics = scene.font_metrics(17.0, 400).expect("a font");
    assert!(
        (one.first_baseline - metrics.ascender).abs() < 1.0,
        "{one:?} {metrics:?}"
    );
    assert!(
        metrics.ascender > 0.0 && metrics.descender < 0.0 && metrics.cap_height > metrics.x_height
    );

    let text = "một hai ba bốn năm sáu bảy tám chín mười";
    let lines =
        |style: &ParagraphStyle| scene.measure_text(text, &run(text, body.clone()), style, 80.0);
    let all = lines(&ParagraphStyle::default());
    assert!(all.line_count >= 3, "{all:?}");
    assert!(all.last_baseline > all.first_baseline);
    let two = lines(&ParagraphStyle {
        max_lines: 2,
        ..ParagraphStyle::default()
    });
    assert_eq!(two.line_count, 2);
    assert!(two.truncated);
    let centered = scene.measure_text(
        text,
        &run(text, body.clone()),
        &ParagraphStyle {
            align: TextAlign::Center,
            ..ParagraphStyle::default()
        },
        f32::INFINITY,
    );
    assert_eq!(
        centered.line_count, 1,
        "centered in unbounded width: {centered:?}"
    );
    let spaced = lines(&ParagraphStyle {
        line_spacing: 10.0,
        ..ParagraphStyle::default()
    });
    let added = spaced.height - all.height;
    let expected = 10.0 * (all.line_count - 1) as f32;
    assert!(
        (added - expected).abs() <= 2.0,
        "added {added}, expected {expected}"
    );
}

#[test]
fn styles_runs_separately() {
    let scene = scene_with_fonts();
    let text = "Big small";
    let big = RunStyle {
        size: 40.0,
        ..RunStyle::default()
    };
    let small = RunStyle {
        size: 10.0,
        ..RunStyle::default()
    };
    let style = ParagraphStyle::default();
    let mixed = scene.measure_text(
        text,
        &[
            Run {
                range: 4..9,
                style: small.clone(),
            },
            Run {
                range: 0..3,
                style: big.clone(),
            },
        ],
        &style,
        f32::INFINITY,
    );
    let all_big = scene.measure_text(text, &run(text, big), &style, f32::INFINITY);
    let all_small = scene.measure_text(text, &run(text, small), &style, f32::INFINITY);
    assert!(all_small.width < mixed.width && mixed.width < all_big.width);
    assert_eq!(
        mixed.height, all_big.height,
        "the line is as tall as its biggest run"
    );
    // A range that ends inside "ế" is cut back to a whole character.
    let text = "tiếng";
    scene.measure_text(
        text,
        &[Run {
            range: 0..3,
            style: RunStyle::default(),
        }],
        &style,
        f32::INFINITY,
    );
}

#[test]
fn places_the_caret_and_finds_touched_offsets() {
    let scene = scene_with_fonts();
    let style = ParagraphStyle::default();
    let caret = |text: &str, offset: usize, width: f32| {
        scene.text_caret(text, &run(text, RunStyle::default()), &style, width, offset)
    };
    let text = "Xin chào ạ";
    let start = caret(text, 0, f32::INFINITY);
    assert_eq!(start.x, 0.0);
    assert!(start.height > 17.0 && start.height < 24.0, "{start:?}");
    // Offsets are bytes: "à" and "ạ" take two and three of them.
    let after_chao = caret(text, "Xin chào".len(), f32::INFINITY);
    let end = caret(text, text.len(), f32::INFINITY);
    let width = scene
        .measure_text(text, &run(text, RunStyle::default()), &style, f32::INFINITY)
        .width;
    assert!(
        0.0 < after_chao.x && after_chao.x < end.x,
        "{after_chao:?} {end:?}"
    );
    assert!((end.x - width).abs() < 1.0, "{end:?} vs width {width}");
    // An offset inside "à" goes back to its start.
    assert_eq!(
        caret(text, "Xin ch".len() + 1, f32::INFINITY),
        caret(text, "Xin ch".len(), f32::INFINITY)
    );

    // A wrapped line: the offset after the space starts the next line.
    let wrapped = caret(text, "Xin ".len(), 40.0);
    assert_eq!(wrapped.x, 0.0);
    assert!(wrapped.y > start.y + 15.0, "{wrapped:?}");

    // Empty text, and the empty line after a final newline, still get a caret
    // as tall as the run's font.
    let big = RunStyle {
        size: 34.0,
        ..RunStyle::default()
    };
    let empty = scene.text_caret("", &run("", big.clone()), &style, f32::INFINITY, 0);
    assert_eq!(empty.x, 0.0);
    assert!(empty.height > 34.0, "{empty:?}");
    let newline = caret("ab\n", 3, f32::INFINITY);
    assert_eq!(newline.x, 0.0);
    assert!(newline.y > start.y + 15.0, "{newline:?}");

    // Touching text finds the nearest boundary, in bytes.
    let at = |x: f32, y: f32| {
        scene.text_offset_at(
            text,
            &run(text, RunStyle::default()),
            &style,
            f32::INFINITY,
            Point::new(x, y),
        )
    };
    assert_eq!(at(-5.0, 10.0), 0);
    assert_eq!(at(after_chao.x + 0.5, 10.0), "Xin chào".len());
    assert_eq!(at(500.0, 10.0), text.len());
}

#[test]
fn casts_shadows_unless_masked() {
    let card = Layer {
        frame: Rect::from_xywh(20.0, 20.0, 40.0, 40.0),
        background_color: Color::RED,
        shadow_color: Color::BLACK,
        shadow_offset: Vector::new(10.0, 10.0),
        shadow_radius: 0.0,
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(card);
    let image = scene.render();
    assert_eq!(pixel(&image, 40, 40), Color::RED);
    assert_eq!(pixel(&image, 65, 65), Color::BLACK, "the shadow, offset");
    assert_eq!(pixel(&image, 15, 15), Color::WHITE);

    scene.layer_mut(id).unwrap().masks_to_bounds = true;
    let image = scene.render();
    assert_eq!(pixel(&image, 65, 65), Color::WHITE);

    // No background, so the shadow is the blurred group: here a sublayer
    // that sticks out to the right of its parent.
    let group = Layer {
        frame: Rect::from_xywh(10.0, 10.0, 20.0, 20.0),
        shadow_color: Color::BLACK,
        shadow_offset: Vector::new(0.0, 10.0),
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(group);
    let child = scene.create_layer();
    *scene.layer_mut(child).unwrap() = Layer {
        frame: Rect::from_xywh(40.0, 0.0, 20.0, 20.0),
        background_color: Color::BLUE,
        ..Layer::default()
    };
    scene.add_sublayer(id, child);
    let image = scene.render();
    assert_eq!(pixel(&image, 60, 20), Color::BLUE);
    assert_eq!(
        pixel(&image, 60, 35),
        Color::BLACK,
        "below the sublayer, outside the parent"
    );
    assert_eq!(
        pixel(&image, 20, 35),
        Color::WHITE,
        "nothing drawn there to cast one"
    );
}

#[test]
fn blurs_both_kinds_of_shadow_alike() {
    // An opaque card takes the quick path, an almost opaque one the group's.
    let shadow_at = |alpha: u8| {
        let mut scene = Scene::new(100.0, 100.0, 2.0);
        let root = scene.root();
        scene.layer_mut(root).unwrap().background_color = Color::WHITE;
        let card = scene.create_layer();
        *scene.layer_mut(card).unwrap() = Layer {
            frame: Rect::from_xywh(20.0, 20.0, 40.0, 40.0),
            background_color: Color::from_argb(alpha, 255, 0, 0),
            corner_radius: 8.0,
            shadow_color: Color::BLACK,
            shadow_offset: Vector::new(0.0, 6.0),
            shadow_radius: 16.0,
            ..Layer::default()
        };
        scene.add_sublayer(root, card);
        let image = scene.render();
        // Pixels below the card, which ends 120 pixels down.
        [130, 140, 160].map(|y| pixel(&image, 80, y).r())
    };
    let (quick, group) = (shadow_at(255), shadow_at(254));
    for (quick, group) in quick.iter().zip(group) {
        assert!(quick.abs_diff(group) <= 6, "{quick} vs {group}");
    }
    assert!(
        quick[0] < 250,
        "a soft shadow reaches 10 points below: {quick:?}"
    );
}

#[test]
fn masks_to_paths_and_draws_shapes() {
    let mut circle = PathBuilder::new();
    circle.add_circle((50.0, 50.0), 40.0, None);
    let masked = Layer {
        frame: Rect::from_xywh(0.0, 0.0, 100.0, 100.0),
        background_color: Color::BLUE,
        mask: Some(circle.detach()),
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(masked);
    let image = scene.render();
    assert_eq!(pixel(&image, 50, 50), Color::BLUE);
    assert_eq!(pixel(&image, 5, 5), Color::WHITE, "outside the circle");
    assert_eq!(
        scene.hit_test((5.0, 5.0)),
        Some(scene.root()),
        "masked away"
    );
    assert_eq!(scene.hit_test((50.0, 50.0)), Some(id));

    let mut triangle = PathBuilder::new();
    triangle
        .move_to((10.0, 90.0))
        .line_to((50.0, 10.0))
        .line_to((90.0, 90.0))
        .close();
    let shape = Shape {
        path: triangle.detach(),
        fill: Color::GREEN,
        stroke: Color::BLACK,
        line_width: 4.0,
        dashes: vec![10.0],
        ..Shape::default()
    };
    let layer = Layer {
        frame: Rect::from_xywh(0.0, 0.0, 100.0, 100.0),
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(layer);
    assert!(scene.set_shape(id, &shape));
    let image = scene.render();
    assert_eq!(pixel(&image, 50, 60), Color::GREEN);
    assert_eq!(pixel(&image, 10, 10), Color::WHITE);
    // Along the bottom edge the stroke alternates dashes and gaps of 10.
    let edge: Vec<bool> = (15..85)
        .map(|x| pixel(&image, x, 90) == Color::BLACK)
        .collect();
    assert!(edge.contains(&true) && edge.contains(&false), "dashed");
}

#[test]
fn fills_gradients() {
    let layer = Layer {
        frame: Rect::from_xywh(0.0, 0.0, 100.0, 100.0),
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(layer);
    let linear = Gradient {
        kind: GradientKind::Linear {
            start: Point::new(0.0, 0.0),
            end: Point::new(100.0, 0.0),
        },
        colors: vec![Color::RED, Color::BLUE],
        locations: vec![],
    };
    assert!(scene.set_gradient(id, &linear));
    let image = scene.render();
    let (left, middle, right) = (
        pixel(&image, 1, 50),
        pixel(&image, 50, 50),
        pixel(&image, 98, 50),
    );
    assert!(left.r() > 240 && left.b() < 15, "{left:?}");
    assert!(right.b() > 240 && right.r() < 15, "{right:?}");
    assert!(middle.r().abs_diff(middle.b()) < 20, "{middle:?}");

    let conic = Gradient {
        kind: GradientKind::Conic {
            center: Point::new(50.0, 50.0),
            start_angle: 0.0,
            end_angle: std::f32::consts::TAU,
        },
        colors: vec![Color::RED, Color::BLUE],
        locations: vec![0.0, 1.0],
    };
    assert!(scene.set_gradient(id, &conic));
    let image = scene.render();
    // Clockwise from the right: a quarter turn is still mostly red.
    assert!(pixel(&image, 50, 90).r() > pixel(&image, 50, 10).r());

    let one_color = Gradient {
        colors: vec![Color::RED],
        ..linear.clone()
    };
    assert!(!scene.set_gradient(id, &one_color));
    let bad_locations = Gradient {
        locations: vec![0.5],
        ..linear
    };
    assert!(!scene.set_gradient(id, &bad_locations));
}

#[test]
fn places_images_by_content_mode() {
    // A 20 × 10 pixel image at 2x: 10 × 5 points, red.
    let rgba: Vec<u8> = [255, 0, 0, 255].repeat(20 * 10);
    let layer = Layer {
        frame: Rect::from_xywh(0.0, 0.0, 100.0, 100.0),
        content_mode: ContentMode::ScaleAspectFit,
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(layer);
    assert!(
        !scene.set_image_pixels(id, (20, 10), &rgba[1..], 80, false, 2.0),
        "too short"
    );
    assert!(scene.set_image_pixels(id, (20, 10), &rgba, 80, false, 2.0));
    let image = scene.render();
    // Fit: 100 × 50, centered vertically.
    assert_eq!(pixel(&image, 50, 50), Color::RED);
    assert_eq!(pixel(&image, 50, 10), Color::WHITE);

    scene.layer_mut(id).unwrap().content_mode = ContentMode::TopLeft;
    let image = scene.render();
    assert_eq!(pixel(&image, 2, 2), Color::RED);
    assert_eq!(
        pixel(&image, 12, 2),
        Color::WHITE,
        "10 points wide at its own size"
    );

    let rect = image_rect(
        ContentMode::ScaleAspectFill,
        Size::new(100.0, 100.0),
        Size::new(10.0, 5.0),
    );
    assert_eq!(rect, Rect::from_xywh(-50.0, 0.0, 200.0, 100.0));
    let rect = image_rect(
        ContentMode::BottomRight,
        Size::new(100.0, 100.0),
        Size::new(10.0, 5.0),
    );
    assert_eq!(rect, Rect::from_xywh(90.0, 95.0, 10.0, 5.0));

    // A template image takes the tint where it is opaque.
    scene.layer_mut(id).unwrap().content_tint = Color::BLUE;
    let image = scene.render();
    assert_eq!(pixel(&image, 2, 2), Color::BLUE);
    assert_eq!(pixel(&image, 12, 2), Color::WHITE);
}

#[test]
fn fills_the_background_of_runs() {
    let mut scene = scene_with_fonts();
    let root = scene.root();
    scene.layer_mut(root).unwrap().background_color = Color::WHITE;
    let id = scene.create_layer();
    scene.layer_mut(id).unwrap().frame = Rect::from_xywh(0.0, 0.0, 200.0, 40.0);
    assert!(scene.add_sublayer(root, id));
    let text = "Iris Iris";
    let runs = [Run {
        range: 5..9,
        style: RunStyle {
            background: Color::YELLOW,
            ..RunStyle::default()
        },
    }];
    assert!(scene.set_text(id, text, &runs, &ParagraphStyle::default()));
    let image = scene.render();
    let width = scene
        .measure_text(text, &runs, &ParagraphStyle::default(), f32::INFINITY)
        .width;
    // The top of the second word's line box, above its glyphs.
    assert_eq!(pixel(&image, width as i32 - 3, 1), Color::YELLOW);
    assert_eq!(pixel(&image, 1, 1), Color::WHITE);
}

#[test]
fn animates_on_the_scene_clock() {
    let layer = Layer {
        frame: Rect::from_xywh(0.0, 0.0, 50.0, 50.0),
        background_color: Color::BLACK,
        ..Layer::default()
    };
    let (mut scene, id) = scene_with_layer(layer);
    scene.set_time(5.0);
    let mut fade = Animation::new(Value::Opacity(0.0), Value::Opacity(1.0), 2.0);
    fade.timing = Timing::LINEAR;
    assert!(scene.add_animation(id, fade));
    let mut slide = Animation::new(
        Value::Frame(Rect::from_xywh(0.0, 0.0, 50.0, 50.0)),
        Value::Frame(Rect::from_xywh(50.0, 0.0, 50.0, 50.0)),
        2.0,
    );
    slide.delay = 1.0;
    assert!(scene.add_animation(id, slide));
    assert!(!scene.add_animation(
        id,
        Animation::new(Value::Opacity(0.0), Value::CornerRadius(1.0), 1.0)
    ));
    assert!(scene.is_animating());

    scene.set_time(6.0);
    assert_eq!(
        scene.shown_value(id, Value::Opacity(0.0)),
        Some(Value::Opacity(0.5)),
        "what shows midway, for an animation that interrupts"
    );
    assert_eq!(
        scene.shown_value(id, Value::CornerRadius(9.0)),
        Some(Value::CornerRadius(0.0)),
        "the layer's own value where nothing animates"
    );
    let gray = pixel(&scene.render(), 25, 25);
    assert!((120..=135).contains(&gray.r()), "half faded in: {gray:?}");

    scene.set_time(10.0);
    let image = scene.render();
    assert!(!scene.is_animating());
    assert_eq!(
        pixel(&image, 25, 25),
        Color::BLACK,
        "back to the layer's own values"
    );
    assert_eq!(pixel(&image, 75, 25), Color::WHITE);
}

#[test]
fn hit_tests_front_to_back_through_transforms() {
    let mut scene = Scene::new(100.0, 100.0, 1.0);
    let root = scene.root();
    let back = scene.create_layer();
    let front = scene.create_layer();
    let child = scene.create_layer();
    for (id, frame) in [
        (back, Rect::from_xywh(0.0, 0.0, 60.0, 60.0)),
        (front, Rect::from_xywh(40.0, 40.0, 40.0, 40.0)),
        // Sticks out of `front` to the right.
        (child, Rect::from_xywh(30.0, 0.0, 20.0, 20.0)),
    ] {
        scene.layer_mut(id).unwrap().frame = frame;
    }
    scene.add_sublayer(root, back);
    scene.add_sublayer(root, front);
    scene.add_sublayer(front, child);

    assert_eq!(scene.hit_test((10.0, 10.0)), Some(back));
    assert_eq!(
        scene.hit_test((50.0, 50.0)),
        Some(front),
        "in front of back"
    );
    assert_eq!(
        scene.hit_test((85.0, 45.0)),
        Some(child),
        "outside its parent"
    );
    scene.layer_mut(front).unwrap().masks_to_bounds = true;
    assert_eq!(scene.hit_test((85.0, 45.0)), Some(root));
    scene.layer_mut(front).unwrap().hidden = true;
    assert_eq!(scene.hit_test((50.0, 50.0)), Some(back));

    // Scaled to half about its center, `back` covers 15…45 only.
    scene.layer_mut(back).unwrap().transform = [0.5, 0.0, 0.0, 0.5, 0.0, 0.0];
    assert_eq!(scene.hit_test((10.0, 10.0)), Some(root));
    assert_eq!(scene.hit_test((20.0, 20.0)), Some(back));
    assert_eq!(scene.hit_test((-1.0, 0.0)), None, "outside the scene");
}

#[test]
fn encodes_frames_on_other_threads() {
    let (mut scene, _) = scene_with_layer(Layer::default());
    let frame = scene.render();
    let png = std::thread::spawn(move || encode(&frame, ImageFormat::Png, 0))
        .join()
        .unwrap()
        .expect("encoded");
    assert!(png.starts_with(b"\x89PNG"));
    // Its header gives the pixel size: a 100-point scene at 1x.
    assert_eq!(Scene::image_size(&png), Some((100, 100)));
    assert_eq!(Scene::image_size(b"not an image"), None);
    // The next render draws into a copy, leaving the earlier frame intact.
    let earlier = scene.render();
    scene.layer_mut(scene.root()).unwrap().background_color = Color::BLUE;
    let later = scene.render();
    assert_eq!(pixel(&earlier, 0, 0), Color::WHITE);
    assert_eq!(pixel(&later, 0, 0), Color::BLUE);
}

#[test]
fn layout_solver_keeps_required_constraints_and_meets_wishes_as_far_as_they_allow() {
    let mut solver = LayoutSolver::new();
    let (x, width) = (solver.add_variable(), solver.add_variable());
    solver
        .add(&[(x, 1.0)], -16.0, Relation::Equal, REQUIRED)
        .unwrap();
    let right = solver
        .add(&[(x, 1.0), (width, 1.0)], -374.0, Relation::Equal, REQUIRED)
        .unwrap();
    assert_eq!(solver.value(width), 358.0);
    // A wish gives way to the required constraints, and holds once they let it.
    let wish = solver
        .add(&[(width, 1.0)], -100.0, Relation::Equal, 1000.0)
        .unwrap();
    assert_eq!(solver.value(width), 358.0);
    assert!(solver.remove(right));
    assert_eq!(solver.value(width), 100.0);
    // A stronger wish wins; an inequality bounds.
    solver
        .add(&[(width, 1.0)], -200.0, Relation::Equal, 2000.0)
        .unwrap();
    assert_eq!(solver.value(width), 200.0);
    solver
        .add(&[(width, 1.0)], -150.0, Relation::LessOrEqual, REQUIRED)
        .unwrap();
    assert_eq!(solver.value(width), 150.0);
    // A contradiction is refused and changes nothing.
    assert_eq!(
        solver.add(&[(x, 1.0)], -20.0, Relation::Equal, REQUIRED),
        None
    );
    assert_eq!(
        solver.add(&[(width, 1.0)], -160.0, Relation::GreaterOrEqual, REQUIRED),
        None
    );
    assert_eq!((solver.value(x), solver.value(width)), (16.0, 150.0));
    assert!(solver.remove(wish));
    assert!(!solver.remove(wish));
    assert_eq!(
        solver.add(&[(9, 1.0)], 0.0, Relation::Equal, REQUIRED),
        None
    );
    assert_eq!(solver.value(9), 0.0);
}
