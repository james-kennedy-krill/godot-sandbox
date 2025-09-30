shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float border_width  : hint_range(0.0, 0.5) = 0.03; // thickness in UV space
uniform float feather       : hint_range(0.0, 0.2) = 0.02; // soft edge
uniform float glow_strength : hint_range(0.0, 8.0) = 2.0;  // border emission
uniform vec4  border_color  : source_color = vec4(1.0);    // usually white

// When > 0.5, fill the inside with this color; when 0, inside is transparent
uniform float fitted = 0.0;
uniform vec4  fitted_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);
// Optional: separate glow for fill (often 0)
uniform float fill_glow_strength : hint_range(0.0, 8.0) = 0.0;

void fragment() {
    vec2 uv = UV;

    // Distance to the nearest edge of the quad
    float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

    // Border mask: 1 at border, 0 inside
    float edge = 1.0 - smoothstep(border_width, border_width + feather, d);

    // Interior mask: 1 away from border (excludes the feathered rim), 0 near border
    float interior = smoothstep(border_width, border_width + feather, d);

    // Border contribution (kept even when fitted)
    vec3 border_rgb = border_color.rgb * glow_strength;
    float border_a = edge * border_color.a;

    // Fill contribution (only when fitted is on)
    float fill_on = step(0.5, fitted);
    float fill_mask = interior * fill_on;
    vec3 fill_rgb = fitted_color.rgb * fill_glow_strength;
    float fill_a = fitted_color.a * fill_mask;

    // Combine (border sits over the feathered rim, fill covers inside)
    vec3 rgb = border_rgb * edge + fill_rgb * fill_mask;
    float alpha = border_a + fill_a;

    COLOR = vec4(rgb, alpha);
}
