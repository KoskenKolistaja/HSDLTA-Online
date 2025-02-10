shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform vec3 light_color: source_color;
uniform vec3 shadow_color: source_color;
uniform float line_strength: hint_range(0.0, 0.3, 0.001) = 0.01;
uniform float color_boost: hint_range(0.0, 1.0, 0.01) = 0.0;

uniform sampler2D noise: repeat_enable;
uniform float noise_strength: hint_range(0.0, 3.0, 0.001) = 0.1;



void fragment() {
	vec3 orig_color = texture(screen_texture, SCREEN_UV).rgb;
	float avg = (orig_color.r + orig_color.g + orig_color.b) / 3.0;
	
	float error_line = sin(SCREEN_UV.y*550.0-TIME*5.0);
	avg += error_line*line_strength;
	float frame_time = floor(TIME * 8.0) / 8.0;
	avg += texture(noise, UV + frame_time).r * noise_strength;
	avg = min(avg, 1.0);
	
	vec3 color = mix(shadow_color, light_color, avg);
	
	
	COLOR = vec4(color + color * color_boost, 1.0);
}
