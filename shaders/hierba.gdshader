shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;

// Hierba. Todas las hojas viven en un solo MultiMeshInstance3D, asi que todo
// esto se ejecuta una vez por hoja y por fotograma, y no hay miles de nodos.
//
// Dos cosas:
//
// 1) El viento. La textura "viento" es un mapa del campo dividido en celdas
//    (las zonas de viento): cada celda guarda una direccion y una fuerza, y se
//    va actualizando sola. La hoja busca la celda que tiene debajo, y como el
//    filtro es lineal el viento no tiene costuras de celda. Al final se ve una
//    ola que cruza el campo en vez de un arbol de ruido que hierve.
//
// 2) El corte. Cada hoja lleva en INSTANCE_CUSTOM.x cuanto le queda de altura:
//    1 es de pie y 0 es cortada. La hoja cortada se aplana y desaparece, sin
//    tocar un solo vertice desde el juego. Por eso se corta tan barato.

uniform sampler2D viento : filter_linear, repeat_disable;
uniform float tiempo = 0.0;
// Fuerza global. Multiplica a todo lo demas. Ojo: va en proporcion de la altura
// de la hoja, no en metros del mundo, asi que 0,25 dobla la punta de una hoja
// de 38 cm unos 10 cm.
uniform float fuerza : hint_range(0.0, 2.0, 0.01) = 0.25;
uniform vec3 color_pie : source_color = vec3(0.098, 0.216, 0.063);
uniform vec3 color_punta : source_color = vec3(0.353, 0.545, 0.157);

varying float v_altura;
varying float v_corte;
varying float v_tono;


void vertex() {
	// En un MultiMesh el vertex shader NO ve la matriz de cada instancia: solo
	// ve la del nodo, que ahora es la de un cuadrante entero (unas 1.500 de las
	// 108.960 que tiene el campo). Asi que no puede
	// saber donde esta cada hoja ni cuanto mide. Lo que si ve son los datos de
	// la instancia, y ahi va todo lo que hace falta:
	//
	//   x = CUANTO LE QUEDA de altura: 1 de pie, 0 cortada
	//   y = donde cae la hoja en el mapa del viento, en 0..1
	//   z = lo mismo en la otra direccion
	//   w = el tono de la hoja
	//
	// Ojo al signo: aqui x es lo que QUEDA, no lo que se ha cortado. Leerlo
	// al reves hacia que la hierba de pie salia tumbada y la cortada salia de
	// pie, justo al contrario, y por eso solo se veia donde habias pasado la
	// maquina.
	//
	// La fase del aleteo y la rigidez salen del tono con una mezcla, porque si
	// no harian falta dos canales mas y solo hay cuatro.
	float enpie = clamp(INSTANCE_CUSTOM.x, 0.0, 1.0);
	float corte = 1.0 - enpie;
	float tono = INSTANCE_CUSTOM.w;
	float fase = fract(tono * 7.31) * 6.2831853;
	float rigidez_hoja = 0.75 + 0.5 * tono;

	// textureLod y no texture: en el vertex no hay derivadas, y pedir el nivel
	// 0 a mano es lo que evita el aviso del compilador. El filtro de la textura
	// es lineal, asi que entre celda y celda no hay costuras aunque la UV caiga
	// en mitad de dos.
	vec2 uv = vec2(INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z);
	vec4 zona = textureLod(viento, uv, 0.0);
	vec2 dir = zona.xy * 2.0 - 1.0;
	dir = normalize(dir + vec2(0.0001, 0.0002));
	// Proporcion de la altura de la hoja que se dobla, no metros del mundo.
	float empuje = zona.z * fuerza * rigidez_hoja;

	// 0 en la raiz, 1 en la punta. En el fragmento se usa para el degradado.
	v_altura = clamp(VERTEX.y, 0.0, 1.0);
	v_corte = corte;
	v_tono = tono;

	// La hoja se dobla mucho mas arriba que abajo, y al cortarla se dobla
	// menos, porque cada hoja mas corta tiene menos palanca.
	float alto = v_altura * enpie;
	float curva = alto * alto;
	// Cada hoja con su propio aleteo, ademas del viento de la zona. Si todas se
	// movieran con el mismo ritmo parecerian un cartel de plastico.
	float aleteo = sin(tiempo * 2.3 + fase) * 0.06;
	// El empuje va en proporcion de la altura de la hoja y NO en metros del
	// mundo, y por eso no hay que mirar la matriz de la instancia (que aqui no
	// se ve). Antes se intentaba pasar el viento a coordenadas de hoja
	// dividiendo por el grosor, y eso multiplicaba el empuje por 22: las hojas
	// salian despedidas varios metros y no se veia ninguna. Las cortadas si se
	// veian, porque al estar tumbadas la curva es cero y no hay empuje.
	VERTEX.x += dir.x * (empuje + aleteo) * curva;
	VERTEX.z += dir.y * (empuje + aleteo) * curva;
	// Cortada: todos los vertices caen al suelo y el triangulo se degenera, con
	// lo que la hoja no pinta nada. Sin tocar la geometria desde el juego.
	VERTEX.y = alto;
	// El tocón se estrecha ademas de bajarse: si no, un corte de 5 cm de alto
	// pareceria una alfombra.
	VERTEX.x *= mix(0.5, 1.0, enpie);
	// La normal se inclina con el viento, para que el doblez se note con la
	// luz y no solo con la silueta.
	NORMAL = normalize(vec3(-dir.x * curva * 0.7, 0.3 * curva, 1.0));
}


void fragment() {
	// Con cull_disabled la cara de atras recibe la normal del reves y la hoja
	// se veria negra. Girandola hacia la camara el campo se ve parejo de lado
	// y de frente, que es como se ve la hierba de verdad.
	NORMAL = normalize(mix(NORMAL, normalize(VIEW), 0.55));
	vec3 c = mix(color_pie, color_punta, v_altura);
	// Cada hoja con un tono algo distinto, para que no se vea la repeticion.
	c *= 0.82 + 0.36 * v_tono;
	// La punta es mas clara: la luz la atraviesa.
	c += color_punta * v_altura * 0.16;
	// Lo cortado se ve mas seco.
	c = mix(c, c * vec3(0.84, 0.80, 0.60), v_corte);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
