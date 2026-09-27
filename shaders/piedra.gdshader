shader_type spatial;
render_mode cull_back, diffuse_burley;

// Granito de Galicia. Una piedra de un solo color parece un plastico gris, asi
// que aqui se hacen tres cosas a la vez: el TONO de cada sillar por separado,
// las juntas entre sillares mas oscuras, y el musgo que sale por abajo, que es
// donde de verdad sale.
//
// El patron de sillares va en el espacio del mundo y no en la UV, y se elige
// el plano con la normal. Eso es un triplanar de manual: se podria hacer
// mezcla entre los tres planos, pero en un muro de piedra la mezcla se nota
// como una mancha en las esquinas, y con elegir uno solo el muro sale todo de
// la misma piedra.

// El lenguaje de sombreado de Godot no trae noise() ni hash(), asi que el ruido
// de valor va montado a pelo, igual que en el suelo.
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// El ruido de celdas para el grano de la piedra.
float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.7, 0.4));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

uniform vec3 piedra_clara : source_color = vec3(0.56, 0.55, 0.53);
uniform vec3 piedra_oscura : source_color = vec3(0.27, 0.27, 0.29);
uniform vec3 piedra_calida : source_color = vec3(0.47, 0.42, 0.36);
uniform vec3 musgo : source_color = vec3(0.20, 0.28, 0.13);
uniform float cantidad_musgo : hint_range(0.0, 1.0) = 0.5;
uniform float alto_musgo : hint_range(0.1, 3.0) = 0.9;
uniform float tamano_piedra : hint_range(0.15, 1.5) = 0.42;
uniform float fuerza_junta : hint_range(0.0, 1.0) = 0.55;
uniform float grano : hint_range(0.0, 1.0) = 0.3;

varying vec3 v_mundo;
varying vec3 v_normal;
varying float v_alto;


void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// La UV se usa para otra cosa: lleva los metros que hay de piedra encima
	// del suelo, no la posicion en la textura. El musgo lo necesita, y con la
	// posicion en el mundo el musgo saldría en todos los muros a la misma
	// altura del mundo, que en una ladera quiere decir musgo en el aire.
	v_alto = UV.y;
}


void fragment() {
	// El plano con el que se mira: el suelo, o la pared de frente, o la de
	// perfil. Se elige el que mas pesa en la normal.
	vec3 n = abs(v_normal);
	vec2 p;
	if (n.y > n.x && n.y > n.z) {
		p = v_mundo.xz;
	} else if (n.x > n.z) {
		p = v_mundo.zy;
	} else {
		p = v_mundo.xy;
	}

	// Las hileras se desplazan media sillar una fila y otra, que es como se
	// colocan de verdad: si no, las juntas salen todas en linea recta y el muro
	// parece un ladrillo de los de toys.
	float fila = floor(p.y / tamano_piedra);
	p.x += mod(fila, 2.0) * tamano_piedra * 0.5;
	vec2 celda = floor(p / tamano_piedra);
	vec2 dentro = fract(p / tamano_piedra);

	// El tono de cada sillar es suyo, y hay dos vacios para que la piedra no
	// tenga un color medio plano.
	float t1 = hash21(celda);
	float t2 = hash21(celda + 17.3);
	vec3 color = mix(piedra_oscura, piedra_clara, 0.35 + 0.65 * t1);
	// La piedra calida va en las manchas de sílice, que en Galicia son las
	// de color pardo y salen a trozos, no por zonas.
	color = mix(color, piedra_calida, smoothstep(0.62, 0.95, t2) * 0.7);

	// La junta: el borde de la celda, oscurecido y con el grano por encima.
	vec2 borde = min(dentro, 1.0 - dentro);
	float junta = smoothstep(0.0, 0.09, min(borde.x, borde.y));
	color = mix(color * 0.55, color, junta * fuerza_junta + (1.0 - fuerza_junta));

	// El musgo por abajo, y no solo por abajo: sale tambien en las juntas
	// horizontalmente, que es donde se queda el agua.
	float zonas = ruido(p * 1.7);
	float verde = smoothstep(alto_musgo, 0.0, v_alto) * smoothstep(0.35, 0.7, zonas);
	verde += smoothstep(0.85, 1.0, zonas) * (1.0 - junta) * 0.5;
	verde = clamp(verde * cantidad_musgo, 0.0, 1.0);
	color = mix(color, musgo, verde);

	// El grano fino, que es lo que hace que de lejos la piedra parezca piedra y
	// no un color liso.
	float fino = hash31(floor(v_mundo * 34.0));
	color *= 1.0 + (fino - 0.5) * grano;
	ALBEDO = color;
	ROUGHNESS = 0.9 - verde * 0.15;
	SPECULAR = 0.1;
}
