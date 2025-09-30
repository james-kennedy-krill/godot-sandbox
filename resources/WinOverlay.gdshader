shader_type canvas_item;

uniform vec2  center_px;  // screen position in pixels
uniform float radius : hint_range(0.0, 4000.0) = 0.0;
uniform float feather : hint_range(0.0, 64.0) = 12.0;
uniform vec4  wipe_color : source_color = vec4(1.0);
uniform vec2  viewport_size;  // <- we'll set this from GDScript

void fragment() {
    // Convert SCREEN_UV to pixel coordinates
    vec2 p = SCREEN_UV * viewport_size;
    float d = distance(p, center_px);

    float a = 1.0 - smoothstep(radius - feather, radius + feather, d);
    COLOR = vec4(wipe_color.rgb, a);
}
