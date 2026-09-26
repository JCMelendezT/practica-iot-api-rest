# Parte 1: memoria

## Que demuestra

Que un dato guardado en la RAM de un proceso es **volátil**: existe mientras el proceso vive y desaparece en cuanto el proceso termina. Ningun disco fue escrito.

Esta es la línea base de la práctica. En las partes siguientes los datos se mueven a lugares que sobreviven: la nube de Ubidots y el disco de MySQL.

## Como funciona

Archivo: `app/parte1-memoria/apirest.py`

No hay base de datos. Los datos son una variable de Python definida en el propio archivo:

```python
books = [
    {
        'id': 1,
        'title': 'La hojarasca',
        'description': 'Good one',
        'author': 'Gabo'
    },
    {
        'id': 2,
        'title': 'El coronel no tiene quien le escriba',
        'description': 'Interesting',
        'author': 'Gabo'
    }
]
```

Dos consecuencias inmediatas:

| Pregunta | Respuesta |
|---|---|
| Dónde se guarda? | En la memoria del proceso de Python |
| Quién escribe en disco? | Nadie. Esta versión no importa nada a MySQL ni a ningun archivo |
| Qué pasa al reiniciar? | La lista vuelve a ser la del archivo: los 2 libros originales |
| Qué pasa con el id? | Lo genera el código: `books[-1]['id'] + 1` |

Sobre el id: se toma el del último elemento de la lista y se le suma uno. Funciona con esta lista porque los ids se generan en orden, pero es una estrategia frágil: si el último libro se borra, el siguiente id puede repetirse. MySQL lo resuelve mejor con `AUTO_INCREMENT`, como se ve en la Parte 3.

## Arranque

```bash
# (dentro de la VM) Entra a la carpeta de la Parte 1.
cd /home/vagrant/app/parte1-memoria
```

```bash
# (dentro de la VM) Arranca el servidor en el puerto 5000.
# DECIR: "Este es el punto de partida: una API REST completa, guardando los datos en memoria."
python3 apirest.py
```

`app.run(debug=True)` escucha en `127.0.0.1:5000`, o sea, solo dentro de la VM. Por eso las consultas `curl` se hacen **desde la segunda sesión de SSH**, no desde Windows. Si quieres exponerlo al host, la forma documentada en `app/parte1-memoria/README-origen.md` es:

```bash
# (dentro de la VM) Arranque alternativo, alcanzable desde Windows.
export FLASK_APP=apirest.py
export FLASK_ENV=development
python3 -m flask run --host=0.0.0.0
```

## Referencia de endpoints

| Metodo | Ruta | Descripción | Código |
|---|---|---|---|
| `GET` | `/books` | Lista todos los libros | 200 |
| `GET` | `/books/<int:book_id>` | Un libro por id | 200 / 404 |
| `POST` | `/books` | Crea un libro. `title` es obligatorio | 201 / 400 |
| `PUT` | `/books/<int:book_id>` | Actualización parcial | 200 / 404 |
| `DELETE` | `/books/<int:book_id>` | Borra un libro | 200 / 404 |

### `GET /books`

```bash
# (dentro de la VM) Trae los 2 libros semilla.
curl -i http://localhost:5000/books
```

Respuesta:

```json
{
  "books": [
    {"author": "Gabo", "description": "Good one", "id": 1, "title": "La hojarasca"},
    {"author": "Gabo", "description": "Interesting", "id": 2, "title": "El coronel no tiene quien le escriba"}
  ]
}
```

### `GET /books/<id>`

```bash
# (dentro de la VM) Trae un libro por id.
curl -i http://localhost:5000/books/2
```

Respuesta:

```json
{
  "book": {"author": "Gabo", "description": "Interesting", "id": 2, "title": "El coronel no tiene quien le escriba"}
}
```

### El 404 que esta versión sí tiene

Esta versión **valida** que la lista tenga resultados antes de indexarla:

```python
book = [book for book in books if book['id'] == book_id]
if len(book) == 0:
    abort(404)
return jsonify({'book': book[0]})
```

Por eso un id inexistente responde 404 y no 500:

```bash
# (dentro de la VM) El id 99 no existe y responde 404.
curl -i http://localhost:5000/books/99
```

Esta validación es la que la Parte 3 **no** tiene, y la que el Desafio en Node vuelve a tener. Es el punto de comparación del ejercicio.

### `POST /books`

`title` es obligatorio; `description` y `author` son opcionales y por defecto valen cadena vacía.

```bash
# (dentro de la VM) Crea un libro. Observa el id de la respuesta.
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Cien anos de soledad","description":"Obra maxima","author":"Garcia Marquez"}' http://localhost:5000/books
```

Respuesta, con el `id` que genero el código:

```json
{
  "book": {"author": "Garcia Marquez", "description": "Obra maxima", "id": 3, "title": "Cien anos de soledad"}
}
```

Sin `title`:

```bash
# (dentro de la VM) Sin title responde 400.
curl -i -X POST -H "Content-Type: application/json" -d '{"author":"Sin titulo"}' http://localhost:5000/books
```

### `PUT /books/<id>`

Es una **actualización parcial**. Cada campo que no envías conserva su valor anterior:

```python
book[0]['title'] = request.json.get('title', book[0]['title'])
book[0]['description'] = request.json.get('description', book[0]['description'])
book[0]['author'] = request.json.get('author', book[0]['author'])
```

```bash
# (dentro de la VM) Actualiza solo el autor del libro 2.
curl -i -X PUT -H "Content-Type: application/json" -d '{"author":"Jorgito"}' http://localhost:5000/books/2
```

Respuesta: el titulo y la descripción siguen siendo los originales, y la respuesta **sí** refleja el cambio.

### `DELETE /books/<id>`

```bash
# (dentro de la VM) Borra el libro 1.
curl -i -X DELETE http://localhost:5000/books/1
```

Respuesta:

```json
{"result": true}
```

A diferencia de la Parte 3, esta versión **sí** responde 404 si el id no existe, porque valida la lista igual que en el `GET`.

## La demostración de la volatilidad

Es la prueba central de esta parte. Se hace en tres pasos, sin escribir nada nuevo.

1. Crear un libro con `POST` y observar que la respuesta trae el `id`.
2. Detener el servidor con `Ctrl+C` en la terminal donde corre. Con `debug=True` puede pedirlo dos veces, porque Flask levanta un proceso auxiliar que recarga los cambios.
3. Volver a arrancar con `python3 apirest.py` y hacer `GET /books`.

El libro creado en el paso 1 ya no está. Solo vuelven los 2 originales, porque siguen siendo los que están escritos en el archivo.

> Que decir: "No borre nada. Detuve el proceso. El dato estaba en la RAM del proceso, y al terminar el proceso el sistema le devolvio esa memoria al sistema operativo. El archivo fuente nunca cambio, así que al arrancar de nuevo se vuelve a leer de ahí. Un dato volátil vive mientras el proceso vive; para que sobreviva tiene que haber un disco, y eso es lo que hace la Parte 3."

Variante para usar en la defensa si hay tiempo: mostrar el archivo mientras el servidor corre y senalar la lista de la parte superior.

```bash
# (dentro de la VM) La unica fuente de verdad de esta parte es el propio archivo.
# DECIR: "Aquí está toda la base de datos de la Parte 1: una lista escrita en el código."
head -n 21 /home/vagrant/app/parte1-memoria/apirest.py
```

## Resumen de lo que hay que saber explicar

| Tema | Que decir |
|---|---|
| Volatilidad | El dato vive en la RAM del proceso y se pierde al detenerlo |
| Generación de id | La hace el código con `books[-1]['id'] + 1`; por eso el `POST` puede devolverlo |
| Validación de `GET` | `if len(book) == 0: abort(404)`, y por eso responde 404 y no 500 |
| `PUT` parcial | Cada campo ausente conserva su valor guardado |
| Sin base de datos | No hay `SELECT` ni `INSERT`; solo listas y diccionarios de Python |

## Siguiente paso

La Parte 1 no tiene ningun mecanismo de credenciales ni de servicio externo. La Parte 2 introduce los dos: una plataforma en la nube y una credencial personal.

Continua con [PARTE-2-UBIDOTS.md](PARTE-2-UBIDOTS.md).
