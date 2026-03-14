shader_type canvas_item;

uniform float speed : hint_range(0, 5) = 1.0;
uniform float width : hint_range(0, 1) = 0.1;
uniform float angle : hint_range(0, 360) = 45.0;
uniform float brightness : hint_range(0, 1) = 0.3;
uniform float pause_duration : hint_range(0, 60) = 15.0; // Tempo de espera em segundos

void fragment() {
    vec4 color = texture(TEXTURE, UV);
	
	// Calcula a duração total do ciclo (movimento + pausa)
    // O movimento da luz leva cerca de 2.0 unidades de tempo no nosso cálculo
    float cycle_duration = 2.0 + pause_duration;
    float time_in_cycle = mod(TIME * speed, cycle_duration);
	// Se o tempo atual for maior que 2.0, a luz fica "escondida" (pausa)
    float sweep = time_in_cycle - 1.0;
    
    // Converte ângulo para radianos
    float rad = radians(angle);
    // Cria a linha de luz baseada no tempo e na posição
    float x = UV.x * cos(rad) - UV.y * sin(rad);

    
    // Calcula a intensidade da luz na posição atual
    float light = smoothstep(sweep - width, sweep, x) - smoothstep(sweep, sweep + width, x);
    
    // Aplica o brilho apenas onde a imagem não é transparente
    color.rgb += light * brightness;
    
    COLOR = color;
}