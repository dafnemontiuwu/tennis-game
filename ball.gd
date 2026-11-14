extends Sprite2D

@export var jugador_1: Node2D
@export var jugador_2: Node2D
@export var esquina_arriba: Marker2D
@export var esquina_abajo: Marker2D
@export var centro_red: Marker2D
@export var marcador: Label
@export var texto_arbitro: Label

const VELOCIDAD = 480.0
const RADIO_GOLPE = 105.0
const MARGEN = 35.0
const JUEGOS_PARA_GANAR = 3

var puntos = [0, 0]
var juegos = [0, 0]
var sacador = 1
var receptor = 2
var ultimo_golpeador = 1
var estado = "saque"

var inicio = Vector2.ZERO
var destino = Vector2.ZERO
var avance = 0.0
var momento_bote = 0.65
var primer_bote = false
var escala_original = Vector2.ONE

func _ready():
	if jugador_1 == null or jugador_2 == null \
	or esquina_arriba == null or esquina_abajo == null \
	or centro_red == null:
		push_error("Faltan jugadores o limites en Inspector")
		set_process(false)
		set_process_input(false)
		return

	escala_original = scale
	_nuevo_saque()
	_anunciar("READY? PLAY!")
	_actualizar_marcador()

func _process(delta):
	_limitar_jugadores()

	if estado == "saque":
		var desplazamiento = -40.0 if sacador == 1 else 40.0
		global_position = _jugador(sacador).global_position \
			+ Vector2(0, desplazamiento)
		scale = escala_original
		return

	if estado != "volando":
		return

	var distancia = maxf(inicio.distance_to(destino), 1.0)
	avance += VELOCIDAD * delta / distancia
	global_position = inicio.lerp(destino, minf(avance, 1.0))

	# Efecto visual de altura y rebote
	var altura = 0.0

	if avance < momento_bote:
		altura = sin(PI * avance / momento_bote)
	else:
		var fase_bote = clampf(
			(avance - momento_bote) / (1.0 - momento_bote),
			0.0, 1.0
		)
		altura = 0.5 * sin(PI * fase_bote)

	scale = escala_original * (1.0 + 0.25 * altura)

	# Primer bote dentro o fuera de la cancha
	if not primer_bote and avance >= momento_bote:
		primer_bote = true

		var izquierda = _izquierda()
		var derecha = _derecha()

		if global_position.x < izquierda \
		or global_position.x > derecha:
			_dar_punto(receptor, "OUT!")
			return

		_anunciar("BOUNCE!")

	# Segundo bote: punto para quien golpeo
	if avance >= 0.98:
		_dar_punto(ultimo_golpeador, "DOUBLE BOUNCE!")

func _input(event):
	if not (event is InputEventKey):
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_R and estado == "fin":
		puntos = [0, 0]
		juegos = [0, 0]
		sacador = 1
		_nuevo_saque()
		_actualizar_marcador()
		_anunciar("READY? PLAY!")
		return

	var quien = 0

	if event.keycode == KEY_SPACE:
		quien = 1
	elif event.keycode == KEY_F:
		quien = 2

	if quien == 0:
		return

	if estado == "saque":
		if quien == sacador:
			_golpear(quien)
		return

	if estado != "volando" or quien != receptor:
		return

	var personaje = _jugador(quien)

	if global_position.distance_to(
		personaje.global_position
	) > RADIO_GOLPE:
		return

	var red_y = centro_red.global_position.y

	# No se puede golpear desde la otra mitad
	if quien == 1 and global_position.y < red_y:
		return

	if quien == 2 and global_position.y > red_y:
		return

	_golpear(quien)

func _golpear(quien):
	ultimo_golpeador = quien
	receptor = 3 - quien
	inicio = global_position

	var personaje = _jugador(quien)

	# La direccion depende de donde golpeas
	var objetivo_x = global_position.x + \
		(global_position.x - personaje.global_position.x) * 2.5

	var linea_y = _arriba() if receptor == 2 else _abajo()
	var extra = -45.0 if receptor == 2 else 45.0

	destino = Vector2(objetivo_x, linea_y + extra)

	# Punto de primer bote en la mitad rival
	var bote_y = lerpf(
		centro_red.global_position.y, linea_y, 0.65
	)

	momento_bote = clampf(
		(bote_y - inicio.y) / (destino.y - inicio.y),
		0.35, 0.88
	)

	avance = 0.0
	primer_bote = false
	estado = "volando"
	_anunciar("PLAY!")

func _dar_punto(ganador, mensaje):
	puntos[ganador - 1] += 1
	var anuncio = mensaje + " POINT: " + _nombre(ganador)

	var otro = 3 - ganador

	if puntos[ganador - 1] >= 4 \
	and puntos[ganador - 1] - puntos[otro - 1] >= 2:

		juegos[ganador - 1] += 1
		puntos = [0, 0]
		anuncio = "GAME! " + _nombre(ganador)
		sacador = 3 - sacador

		if juegos[ganador - 1] >= JUEGOS_PARA_GANAR:
			estado = "fin"
			scale = escala_original
			_actualizar_marcador()
			_anunciar("MATCH! GANA " + _nombre(ganador) \
				+ " | R PARA REINICIAR")
			return

	elif puntos[0] >= 3 and puntos[0] == puntos[1]:
		anuncio += " | DEUCE!"

	_nuevo_saque()
	_actualizar_marcador()
	_anunciar(anuncio)

func _nuevo_saque():
	estado = "saque"
	receptor = 3 - sacador
	primer_bote = false
	avance = 0.0
	scale = escala_original

func _actualizar_marcador():
	if marcador == null:
		return

	var extra = ""

	if puntos[0] >= 3 and puntos[0] == puntos[1]:
		extra = " | DEUCE"

	marcador.text = "GORDITO: " + _texto_puntos(1) \
		+ " | WINNIE: " + _texto_puntos(2) + extra \
		+ "\nJUEGOS: " + str(juegos[0]) \
		+ " - " + str(juegos[1])

func _texto_puntos(quien):
	var mio = puntos[quien - 1]
	var otro = puntos[2 - quien]

	if mio >= 3 and otro >= 3:
		if mio > otro:
			return "AD"
		return "40"

	return ["0", "15", "30", "40"][mini(mio, 3)]

func _anunciar(mensaje):
	if texto_arbitro != null:
		texto_arbitro.text = mensaje

func _jugador(numero):
	return jugador_1 if numero == 1 else jugador_2

func _nombre(numero):
	return "GORDITO" if numero == 1 else "WINNIE"

func _izquierda():
	return minf(
		esquina_arriba.global_position.x,
		esquina_abajo.global_position.x
	)

func _derecha():
	return maxf(
		esquina_arriba.global_position.x,
		esquina_abajo.global_position.x
	)

func _arriba():
	return minf(
		esquina_arriba.global_position.y,
		esquina_abajo.global_position.y
	)

func _abajo():
	return maxf(
		esquina_arriba.global_position.y,
		esquina_abajo.global_position.y
	)

func _limitar_jugadores():
	var red_y = centro_red.global_position.y

	var p1 = jugador_1.global_position
	var p2 = jugador_2.global_position

	jugador_1.global_position = Vector2(
		clampf(p1.x, _izquierda() + MARGEN, _derecha() - MARGEN),
		clampf(p1.y, red_y + MARGEN, _abajo() - MARGEN)
	)

	jugador_2.global_position = Vector2(
		clampf(p2.x, _izquierda() + MARGEN, _derecha() - MARGEN),
		clampf(p2.y, _arriba() + MARGEN, red_y - MARGEN)
	)
