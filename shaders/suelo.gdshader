shader_type spatial;
render_mode cull_back, diffuse_burley;

// Tierra de huerto. Con un color plano el suelo parece un plastico verde, asi
// que se mezclan tres tonos con ruido a tres escalas: las manchas grandes dan la
// idea de terreno, la media separa tierra clara de tierra oscura y humeda, y la
// fina es el grano.

// El lenguaje de sombreado de Godot no trae noise() ni hash(), asi que el ruido
// de valor va montado a pelo. Sin esto no hay forma de variedar el suelo desde
// aqui sin traer una textura.
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Suavizado cuadratico de la celda. Con la interpolacion recta se notan
	// las esquinas y el ruido sale a cuadros.
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

uniform vec3 tierra_seca : source_color = vec3(0.345, 0.259, 0.169);
uniform vec3 tierra_humeda : source_color = vec3(0.145, 0.098, 0.062);
uniform vec3 verdin : source_color = vec3(0.208, 0.271, 0.129);
uniform float cantidad_verdin : hint_range(0.0, 1.0) = 0.3;
uniform float grano : hint_range(0.0, 1.0) = 0.45;
uniform float escala_manchas : hint_range(0.05, 2.0) = 0.28;

varying vec3 v_mundo;


void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	// La posicion del mundo, no la UV: asi las manchas no se repiten con el
	// borde de la malla y no se ve el empalme al alejarse.
	vec2 p = v_mundo.xz;
	float grande = ruido(p * 0.06);
	float media = ruido(p * escala_manchas);
	float fina = ruido(p * 2.7);
	float mezcla = clamp(media * 0.6 + grande * 0.4, 0.0, 1.0);
	vec3 color = mix(tierra_humeda, tierra_seca, smoothstep(0.2, 0.8, mezcla));
	// El verdin sale en las zonas hundidas y sombrias, que es donde de verdad
	// sale el musgo en un huerto.
	float verde = smoothstep(0.45, 0.9, 1.0 - mezcla) * cantidad_verdin;
	color = mix(color, verdin, verde);
	color *= 1.0 + (fina - 0.5) * grano;
	ALBEDO = color;
	ROUGHNESS = 0.94 - verde * 0.2;
	SPECULAR = 0.12;
}
