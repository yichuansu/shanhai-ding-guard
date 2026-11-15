shader_type canvas_item;
// 受击闪白：flash 从 1 衰减到 0。tint 用来叠加状态色（定身蓝、毒涎紫）。

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, tint.rgb, tint.a);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
