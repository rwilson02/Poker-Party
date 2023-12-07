shader_type canvas_item;

uniform vec2 dir = vec2(0,0);
const float SPEED = 0.075;

void fragment() {
	vec2 move = dir * TIME * SPEED;
	COLOR = vec4(texture(TEXTURE, UV + move).rgb / 1.75, 1);
}
