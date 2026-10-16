// C API of OpenKit's render core (crates/render): a layer tree in the style
// of Core Animation's CALayer, drawn with Skia on the CPU into frames.
//
// A scene holds the layers of one window. Geometry is in points, y down, as
// in UIKit; frames have `scale` pixels per point. Colors are 0xAARRGGBB. A
// scene is not thread-safe: use it from one thread. Frames it renders may be
// encoded on any thread.
//
// Functions that take a layer return false and change nothing when the id is
// stale or belongs to no layer. Ids of destroyed layers never become valid
// again.

#ifndef IRISRUN_RENDER_H
#define IRISRUN_RENDER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct IrisScene IrisScene;
typedef struct IrisFrame IrisFrame;
typedef uint64_t IrisLayer;

// What iris_scene_root, iris_layer_new and iris_scene_hit_test return
// without a scene or a layer.
#define IRIS_LAYER_NONE UINT64_MAX

// ---- Text

typedef enum : uint32_t {
  IRIS_TEXT_ALIGN_LEADING = 0,
  IRIS_TEXT_ALIGN_CENTER = 1,
  IRIS_TEXT_ALIGN_TRAILING = 2,
} IrisTextAlign;

// Bits of IrisTextRun.traits.
typedef enum : uint32_t {
  IRIS_TEXT_ITALIC = 1 << 0,
  IRIS_TEXT_UNDERLINE = 1 << 1,
  IRIS_TEXT_STRIKETHROUGH = 1 << 2,
} IrisTextTraits;

// How the bytes [start, end) of a UTF-8 text look. Bytes no run covers get
// 17-point black regular text; a range that splits a character is cut back
// to whole ones.
typedef struct {
  size_t start, end;
  float size;             // points
  uint16_t weight;        // 100 (thin) to 900 (black); 400 is regular
  uint32_t color;         // 0xAARRGGBB, also of underlines and strikethroughs
  uint32_t traits;        // IrisTextTraits
  float letter_spacing;   // points added after each character
  float baseline_offset;  // points the run is raised by
  uint32_t background;    // 0xAARRGGBB filling the run's line boxes; 0 for none
} IrisTextRun;

typedef struct {
  IrisTextAlign align;
  uint32_t max_lines;  // 0: no limit; otherwise the last line ends with "…"
  float line_spacing;  // points added between lines
} IrisParagraphStyle;

// Distances in points from the top of the text.
typedef struct {
  float width, height;
  float first_baseline, last_baseline;
  uint32_t line_count;
  bool truncated;  // max_lines cut lines off
} IrisTextMetrics;

// A caret as tall as the glyphs of its line, in points from the top-left of
// the text.
typedef struct {
  float x, y, height;
} IrisCaret;

// In points, signed as in UIFont: the ascender is positive, the descender
// negative.
typedef struct {
  float ascender, descender, leading, cap_height, x_height;
} IrisFontMetrics;

// ---- Paths

typedef enum : uint32_t {
  IRIS_PATH_MOVE = 0,   // points[0..2]
  IRIS_PATH_LINE = 1,   // points[0..2]
  IRIS_PATH_QUAD = 2,   // control point, end point: points[0..4]
  IRIS_PATH_CUBIC = 3,  // two control points, end point: points[0..6]
  IRIS_PATH_CLOSE = 4,
} IrisPathVerb;

// One step of a path, as CGPathApply hands them out.
typedef struct {
  IrisPathVerb verb;
  float points[6];
} IrisPathElement;

typedef enum : uint32_t {
  IRIS_LINE_CAP_BUTT = 0,
  IRIS_LINE_CAP_ROUND = 1,
  IRIS_LINE_CAP_SQUARE = 2,
} IrisLineCap;

typedef enum : uint32_t {
  IRIS_LINE_JOIN_MITER = 0,
  IRIS_LINE_JOIN_ROUND = 1,
  IRIS_LINE_JOIN_BEVEL = 2,
} IrisLineJoin;

typedef struct {
  uint32_t fill;    // 0 for no fill
  uint32_t stroke;  // 0 for no stroke
  float line_width;
  IrisLineCap line_cap;
  IrisLineJoin line_join;
  float miter_limit;
  bool even_odd;          // the fill rule; false is nonzero winding
  const float *dashes;    // lengths of dashes and gaps in turn; may be NULL
  size_t dash_count;
  float dash_phase;
} IrisShapeStyle;

// ---- Gradients

typedef enum : uint32_t {
  IRIS_GRADIENT_LINEAR = 0,  // from start to end
  IRIS_GRADIENT_RADIAL = 1,  // circles around center, start_radius to end_radius
  IRIS_GRADIENT_CONIC = 2,   // around center, start_angle to end_angle
} IrisGradientKind;

// Coordinates are in the layer's points; angles in radians, clockwise from
// the positive x axis. Only the fields of the kind are read.
typedef struct {
  IrisGradientKind kind;
  const uint32_t *colors;
  const float *locations;  // from 0 to 1, one per color; NULL spaces them evenly
  size_t count;            // at least 2
  float start_x, start_y, end_x, end_y;
  float center_x, center_y;
  float start_radius, end_radius;
  float start_angle, end_angle;
} IrisGradient;

// ---- Animations

typedef enum : uint32_t {
  IRIS_PROPERTY_OPACITY = 0,           // from[0], to[0]
  IRIS_PROPERTY_FRAME = 1,             // x, y, width, height
  IRIS_PROPERTY_TRANSFORM = 2,         // a, b, c, d, tx, ty
  IRIS_PROPERTY_BACKGROUND_COLOR = 3,  // from_color, to_color
  IRIS_PROPERTY_CORNER_RADIUS = 4,     // from[0], to[0]
} IrisProperty;

// A change of one property over time, as CABasicAnimation. The layer's own
// value shows before the animation begins (unless it fills backwards) and
// after it ends, so set the layer to the final value when adding one.
typedef struct {
  IrisProperty property;
  float from[6], to[6];
  uint32_t from_color, to_color;
  double duration;      // seconds
  double delay;         // seconds from now on the scene's clock
  float timing[4];      // cubic Bézier x1, y1, x2, y2; {0.25, 0.1, 0.25, 1} is CA's default
  float repeat_count;   // up to 1 plays once; INFINITY repeats forever
  bool autoreverses;
  bool fills_backwards; // shows `from` until it begins, as CA's backwards fill mode
} IrisAnimation;

// ---- Scenes and frames

typedef enum : uint32_t {
  IRIS_IMAGE_FORMAT_PNG = 0,
  IRIS_IMAGE_FORMAT_JPEG = 1,
} IrisImageFormat;

// Bytes owned by the render core; release them with iris_bytes_free.
typedef struct {
  uint8_t *data;  // NULL on failure
  size_t len;
} IrisBytes;

// A scene width × height points large, with an empty root layer that fills
// it. Release it with iris_scene_free.
IrisScene *iris_scene_new(float width, float height, float scale);
void iris_scene_free(IrisScene *scene);
// Also resizes the root layer.
void iris_scene_resize(IrisScene *scene, float width, float height, float scale);

// Adds a TrueType or OpenType font; false if the data is not a font. Text
// only uses fonts added here, never the machine's, so frames look the same
// everywhere. A character missing from the fonts added first comes from the
// next one that has it.
bool iris_scene_add_font(IrisScene *scene, const uint8_t *data, size_t len);
// The same from a file, mapped instead of read: a large CJK font then takes
// memory only for the glyphs drawn.
bool iris_scene_add_font_file(IrisScene *scene, const char *path);
// The metrics of the first font added.
bool iris_scene_font_metrics(const IrisScene *scene, float size, uint16_t weight,
                             IrisFontMetrics *metrics);

IrisLayer iris_scene_root(const IrisScene *scene);

// Lays text out in lines up to max_width points wide (INFINITY for one line
// per paragraph). paragraph may be NULL for the defaults.
bool iris_scene_measure_text(const IrisScene *scene, const char *utf8, const IrisTextRun *runs,
                             size_t run_count, const IrisParagraphStyle *paragraph,
                             float max_width, IrisTextMetrics *metrics);

// Where the caret goes before the byte `offset` of text laid out as
// iris_scene_measure_text lays it out (or after the last character): on the
// line of that character, which at a soft line break is the next line. An
// offset inside a character goes back to its start.
bool iris_scene_text_caret(const IrisScene *scene, const char *utf8, const IrisTextRun *runs,
                           size_t run_count, const IrisParagraphStyle *paragraph,
                           float max_width, size_t offset, IrisCaret *caret);
// The byte offset of the character boundary nearest to a point in that text,
// for placing the caret where the text is touched.
size_t iris_scene_text_offset_at(const IrisScene *scene, const char *utf8,
                                 const IrisTextRun *runs, size_t run_count,
                                 const IrisParagraphStyle *paragraph, float max_width, float x,
                                 float y);

// The scene's clock in seconds, which animations run on. Callers move it,
// with real time or a virtual clock.
void iris_scene_set_time(IrisScene *scene, double seconds);
// Whether an animation is still to run, so frames still change.
bool iris_scene_is_animating(const IrisScene *scene);

// The front-most layer at a point in scene coordinates, as CALayer.hitTest
// finds it: hidden layers and what a mask clips away are skipped. Uses the
// layers' own values, not animated ones.
IrisLayer iris_scene_hit_test(const IrisScene *scene, float x, float y);

// Draws the tree into a frame. Release it with iris_frame_free; the scene
// may render again meanwhile.
IrisFrame *iris_scene_render(IrisScene *scene);
// Encodes a frame, on any thread; quality (0–100) applies to JPEG.
IrisBytes iris_frame_encode(const IrisFrame *frame, IrisImageFormat format, uint8_t quality);
void iris_frame_free(IrisFrame *frame);
// Renders and encodes in one call.
IrisBytes iris_scene_encode(IrisScene *scene, IrisImageFormat format, uint8_t quality);
void iris_bytes_free(IrisBytes bytes);

// ---- Layers

// A new layer, not in the tree until added to a parent.
IrisLayer iris_layer_new(IrisScene *scene);
// Its sublayers stay alive without a parent. The root cannot be destroyed.
bool iris_layer_destroy(IrisScene *scene, IrisLayer layer);

// Makes child the last sublayer of parent, taking it from its old parent.
bool iris_layer_add_sublayer(IrisScene *scene, IrisLayer parent, IrisLayer child);
// Moves child to index among the sublayers of parent, or to the end if index
// is past it. Fails if that would make a cycle.
bool iris_layer_insert_sublayer(IrisScene *scene, IrisLayer parent, IrisLayer child, size_t index);
bool iris_layer_remove_from_parent(IrisScene *scene, IrisLayer layer);

// Position and size in the parent's coordinates.
bool iris_layer_set_frame(IrisScene *scene, IrisLayer layer, float x, float y, float width, float height);
// An affine transform about the layer's center: {a, b, c, d, tx, ty}, as in
// CGAffineTransform.
bool iris_layer_set_transform(IrisScene *scene, IrisLayer layer, const float transform[6]);
// Applies to the layer and its sublayers as one group.
bool iris_layer_set_opacity(IrisScene *scene, IrisLayer layer, float opacity);
bool iris_layer_set_hidden(IrisScene *scene, IrisLayer layer, bool hidden);
bool iris_layer_set_background_color(IrisScene *scene, IrisLayer layer, uint32_t argb);
bool iris_layer_set_corner_radius(IrisScene *scene, IrisLayer layer, float radius);
// Drawn inside the bounds, above content and sublayers.
bool iris_layer_set_border(IrisScene *scene, IrisLayer layer, float width, uint32_t argb);
// Clips content and sublayers to the rounded bounds.
bool iris_layer_set_masks_to_bounds(IrisScene *scene, IrisLayer layer, bool masks);
// Clips the layer and its sublayers to a path in the layer's coordinates;
// count 0 removes the mask. False for an unknown verb.
bool iris_layer_set_mask(IrisScene *scene, IrisLayer layer, const IrisPathElement *path, size_t count,
                         bool even_odd);
// A shadow of all the layer draws, sublayers included, offset and blurred
// by radius points; argb 0 removes it. Masking to bounds clips it away, as in
// Core Animation.
bool iris_layer_set_shadow(IrisScene *scene, IrisLayer layer, uint32_t argb, float dx, float dy,
                           float radius);
// Where an image goes in the bounds: a raw value of UIView.ContentMode, from
// scaleToFill (0) to bottomRight (12).
bool iris_layer_set_content_mode(IrisScene *scene, IrisLayer layer, uint32_t mode);
// Paints an image's opaque parts in one color, as UIKit draws template images;
// argb 0 draws the image's own colors.
bool iris_layer_set_content_tint(IrisScene *scene, IrisLayer layer, uint32_t argb);

// Content: one of text, an image, a shape or a gradient. Setting one
// replaces the other.
//
// Text in runs, laid out to the layer's width; paragraph may be NULL.
bool iris_layer_set_text(IrisScene *scene, IrisLayer layer, const char *utf8, const IrisTextRun *runs,
                         size_t run_count, const IrisParagraphStyle *paragraph);
// A PNG, JPEG, WebP, GIF or BMP with scale pixels per point; false if it
// cannot be decoded.
bool iris_layer_set_image(IrisScene *scene, IrisLayer layer, const uint8_t *data, size_t len, float scale);
// The pixel size of an encoded image, read from its header; false if it is not one.
bool iris_image_size(const uint8_t *data, size_t len, int32_t *width, int32_t *height);
// RGBA pixels, 8 bits a channel, rows row_bytes apart.
bool iris_layer_set_image_pixels(IrisScene *scene, IrisLayer layer, int32_t width, int32_t height,
                                 const uint8_t *rgba, size_t row_bytes, bool premultiplied, float scale);
// A path, filled and then stroked, as CAShapeLayer draws it. False for an
// unknown verb.
bool iris_layer_set_shape(IrisScene *scene, IrisLayer layer, const IrisPathElement *path, size_t count,
                          const IrisShapeStyle *style);
// Fills the rounded bounds, as CAGradientLayer does. False with fewer than
// two colors or an unknown kind.
bool iris_layer_set_gradient(IrisScene *scene, IrisLayer layer, const IrisGradient *gradient);
bool iris_layer_clear_content(IrisScene *scene, IrisLayer layer);

// Starts an animation, replacing one of the same property.
bool iris_layer_add_animation(IrisScene *scene, IrisLayer layer, const IrisAnimation *animation);
bool iris_layer_remove_animations(IrisScene *scene, IrisLayer layer);
// The value of a property as the layer shows it at the scene's time, as a
// presentation layer has it: an animation's while one runs, else the layer's
// own; into value[6] as IrisAnimation's from, or *color. Either may be NULL.
bool iris_layer_shown_value(const IrisScene *scene, IrisLayer layer, IrisProperty property,
                            float *value, uint32_t *color);

// ---- Layout
//
// Auto Layout's linear constraints over numbered variables, kept solved by the
// Cassowary simplex as they come and go. A solver is not thread-safe.

typedef struct IrisLayoutSolver IrisLayoutSolver;

typedef struct {
  uint32_t variable;
  double coefficient;
} IrisLayoutTerm;

// The strength of a constraint that must hold. Weaker constraints are wishes,
// met as far as the required ones and stronger wishes let them.
#define IRIS_LAYOUT_REQUIRED 1001001000.0

IrisLayoutSolver *iris_layout_solver_new(void);
void iris_layout_solver_free(IrisLayoutSolver *solver);
// A new variable, numbered from 0 up; it is 0 until a constraint moves it.
uint32_t iris_layout_variable_new(IrisLayoutSolver *solver);
// Adds sum(coefficient * variable) + constant <relation> 0, where relation is
// -1 (<=), 0 (==) or 1 (>=), at strength. Returns the constraint's id, or 0,
// changing nothing, for a bad variable or relation, or a required constraint
// that contradicts the required ones in the solver.
uint64_t iris_layout_add(IrisLayoutSolver *solver, const IrisLayoutTerm *terms, size_t count, double constant,
                         int32_t relation, double strength);
// False if the constraint is not in the solver.
bool iris_layout_remove(IrisLayoutSolver *solver, uint64_t constraint);
double iris_layout_value(const IrisLayoutSolver *solver, uint32_t variable);

#ifdef __cplusplus
}
#endif

#endif  // IRISRUN_RENDER_H
