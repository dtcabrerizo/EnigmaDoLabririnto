shader_type spatial;

uniform sampler2D background_tex;
uniform sampler2D symbol_tex;
uniform sampler2D color_tex;

const vec2 bg_grid = vec2(3.0, 1.0);
uniform int tile_type = 0;

uniform int symbol = 0;
const vec2 symbol_grid = vec2(6.0, 4.0);

uniform int color = 0;
const vec2 color_grid = vec2(4.0, 1.0);

const float symbol_scale = 0.4;

uniform float alpha = 1.0;

vec2 atlas_uv(vec2 uv, vec2 grid, vec2 index){
    vec2 cell = 1.0 / grid;
    return uv * cell + index * cell;
}
vec3 srgb_to_linear(vec3 c){
    return pow(c, vec3(2.2));
}

vec4 get_texture_from_grid(sampler2D tex, int index, vec2 grid, vec2 center_uv) {
	float x = mod(float(index), grid.x);
	float y = floor(float(index) / grid.x);
	vec2 index_uv = vec2(x, y);        
	vec2 a_uv = atlas_uv(center_uv, grid, index_uv);
	vec4 ret = texture(tex, a_uv);
	ret.rgb = srgb_to_linear(ret.rgb);
	return ret;
}
void fragment() {

    // fundo
    vec2 bg_index = vec2(float(tile_type), 0.0);
    vec2 bg_uv = atlas_uv(UV, bg_grid, bg_index);
    vec4 bg = texture(background_tex, bg_uv);
	bg.rgb = srgb_to_linear(bg.rgb);

    // UV central do símbolo
    vec2 center_uv = (UV - vec2(0.5)) / symbol_scale + vec2(0.5);

    vec4 sym = vec4(0.0);
	vec4 cir = vec4(0.0);

    // só desenha símbolo dentro da área central
    if(center_uv.x >= 0.0 && center_uv.x <= 1.0 &&
       center_uv.y >= 0.0 && center_uv.y <= 1.0){
		sym = get_texture_from_grid(symbol_tex, symbol, symbol_grid, center_uv);
		cir = get_texture_from_grid(color_tex, color, color_grid, center_uv);		
    }

	
    vec3 albedo;
	if (symbol >= 0) {
		albedo = mix(bg.rgb, sym.rgb, sym.a);
	} else if (color >= 0) {
		albedo = mix(bg.rgb, cir.rgb, cir.a);		
	} else {
		albedo = bg.rgb;
	}
	
    ALBEDO = albedo;
	ALPHA = bg.a - (1.0 - alpha);
}