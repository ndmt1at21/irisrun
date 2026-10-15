// C API of OpenKit's render core (crates/render): a layer tree in the style
// of Core Animation's CALayer, drawn with Skia on the CPU into frames.
//
// A scene holds the layers of one window. Geometry is in points; frames have
// `scale` pixels per point. Colors are 0xAARRGGBB. A scene is not
// thread-safe: use it from one thread.
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
typedef uint64_t IrisLayer;

// What iris_scene_root and iris_layer_new return without a scene.
#define IRIS_LAYER_NONE UINT64_MAX

typedef enum : uint32_t {
  IRIS_TEXT_ALIGN_LEADING = 0,
  IRIS_TEXT_ALIGN_CENTER = 1,
  IRIS_TEXT_ALIGN_TRAILING = 2,
} IrisTextAlign;

typedef struct {
  float size;          // points
  uint16_t weight;     // 100 (thin) to 900 (black); 400 is regular
  uint32_t color;      // 0xAARRGGBB
  IrisTextAlign align;
  uint32_t max_lines;  // 0: no limit; otherwise the last line ends with "…"
} IrisTextStyle;

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

IrisLayer iris_scene_root(const IrisScene *scene);

// The size text takes when its lines may be up to max_width points wide.
bool iris_scene_measure_text(const IrisScene *scene, const char *utf8, const IrisTextStyle *style,
                             float max_width, float *width, float *height);

// Draws the tree and encodes the frame; quality (0–100) applies to JPEG.
IrisBytes iris_scene_encode(IrisScene *scene, IrisImageFormat format, uint8_t quality);
void iris_bytes_free(IrisBytes bytes);

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

// Content: text, laid out to the layer's width, or an image stretched to its
// bounds. Setting one replaces the other.
bool iris_layer_set_text(IrisScene *scene, IrisLayer layer, const char *utf8, const IrisTextStyle *style);
// PNG, JPEG, WebP, GIF or BMP; false if it cannot be decoded.
bool iris_layer_set_image(IrisScene *scene, IrisLayer layer, const uint8_t *data, size_t len);
bool iris_layer_clear_content(IrisScene *scene, IrisLayer layer);

#ifdef __cplusplus
}
#endif

#endif  // IRISRUN_RENDER_H
