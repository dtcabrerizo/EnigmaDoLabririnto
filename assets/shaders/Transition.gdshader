shader_type canvas_item;
uniform float circle_size : hint_range(0.0, 1.05) = 1.0;
uniform vec2 screen_center = vec2(0.5, 0.5);

void fragment() {
    float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
    vec2 uv = vec2(UV.x, (UV.y - 0.5) * ratio + 0.5);
    vec2 center = vec2(screen_center.x, (screen_center.y - 0.5) * ratio + 0.5);
    float dist = distance(uv, center);
    
    // Pegamos a cor que viria do ColorRect (incluindo a modulação/transparência do Tween)
    vec4 color = texture(TEXTURE, UV); 
    
    // O step define o círculo, e multiplicamos pelo COLOR.a original do nó (modulate)
    float mask = step(circle_size, dist);
    COLOR = vec4(COLOR.rgb, mask * COLOR.a);
}