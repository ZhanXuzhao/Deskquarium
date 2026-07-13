shader_type canvas_item;

uniform float wave_speed : hint_range(0.0, 3.0) = 1.2;
uniform float wave_strength : hint_range(0.0, 30.0) = 12.0;
uniform vec4 surface_color : source_color = vec4(0.7, 0.92, 1.0, 0.35);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);

void fragment() {
	float time = TIME * wave_speed;
	
	// 多层级波浪
	float wave1 = sin(UV.x * 8.0 + time * 1.0) * 0.5 + 0.5;
	float wave2 = sin(UV.x * 14.0 + time * 0.7 + 1.3) * 0.5 + 0.5;
	float wave3 = sin(UV.x * 22.0 + time * 1.4 + 2.7) * 0.5 + 0.5;
	float wave = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2);
	
	// 波浪偏移量（像素）
	float wave_offset = (wave - 0.5) * wave_strength;
	
	// 水面高度位置（相对于本节点高度）
	float surface_line = wave_offset;
	
	// 水面主体：从顶部到 surface_line
	float surface = 1.0 - smoothstep(surface_line - 6.0, surface_line + 4.0, UV.y * 100.0);
	
	// 顶部高光衰减
	float top_fade = exp(-UV.y * 8.0);
	
	// 底部淡出
	float bottom_fade = 1.0 - smoothstep(0.0, 0.6, UV.y);
	
	vec4 color = surface_color;
	color.a *= surface * bottom_fade;
	
	// 水面线高光
	float line_glow = exp(-abs(UV.y * 100.0 - wave_offset) * 0.3);
	color += highlight_color * line_glow * 2.0;
	
	COLOR = color;
}
