shader_type canvas_item;

// The progress of the white flash (0.0 = normal, 1.0 = fully white)
uniform float white_progress : hint_range(0.0, 1.0) = 0.0;

// Master transparency control (1.0 = fully opaque, 0.0 = invisible)
uniform float flash_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    
    // 1. Mix original colors with pure white based on progress
    vec3 whitened_rgb = mix(texture_color.rgb, vec3(1.0, 1.0, 1.0), white_progress);
    
    // 2. Multiply original alpha with the custom flash_alpha parameter
    float final_alpha = texture_color.a * flash_alpha;
    
    COLOR = vec4(whitened_rgb, final_alpha);
}