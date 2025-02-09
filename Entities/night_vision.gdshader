shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform vec3 light_color: source_color;
uniform vec3 shadow_color: source_color;


void fragment() {
	vec3 orig_color = texture(screen_texture, SCREEN_UV).rgb;
	float avg = (orig_color.r + orig_color.g + orig_color.b) / 3.0;
	
	float error_line = sin(SCREEN_UV.y*550.0-TIME*5.0);
	avg += error_line*0.2;
	avg = min(avg, 1.0);
	
	vec3 color = mix(shadow_color, light_color, avg);
	
	
	COLOR = vec4(color, 1.0);
	//COLOR = vec4(vec3(error_line), 1.0);
}
