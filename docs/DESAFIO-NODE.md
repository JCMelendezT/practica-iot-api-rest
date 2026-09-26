# Desafio: la misma API en Node.js

## Qué demuestra

Que el entregable real de la práctica es el **contrato REST**, no el framework. `app/desafio-node/server.js` expone la misma API que `app/parte3-mysql/apirest_mysql.py`, con otro lenguaje, otro framework, otro driver y otro puerto, y aun así se comporta igual.

Además corrige cuatro problemas concretos de la línea base de Flask. Ese es el trabajo que se evalúa.

## Por que dos lenguajes

La Parte 3 y el Desafio podría ser el mismo archivo con otros nombres de función, y no habría demostrado nada. El punto es que cambien **las cuatro capas**:

| Capa | Parte 3 | Desafio |
|---|---|---|
| Lenguaje | Python 3 | JavaScript (Node 22) |
| Framework web | Flask 2.3.3 | Express 5.2.1 |
| Driver de MySQL | `Flask-MySQLdb` 1.0.1 sobre `mysqlclient` | `mysql2` 3.24.4 |
| Puerto | 5000 | 3000 |

Lo único que se mantiene es el contrato: mismas rutas, mismos metodos, mismos nombres de campo en el JSON.

> Que decir: "Cambie las cuatro capas y deje el contrato intacto. Eso demuestra que el contrato es la especificación real, y que la implementación es intercambiable."

## Correspondencia Flask contra Express

Para quien viene de Python, esta es la equivalencia útil.

### Leer el cuerpo JSON

| Flask | Express |
|---|---|
| `request.json` | `req.body` |
| (no hace falta configurarlo) | `app.use(express.json())` |

La única línea de configuración extra en Express es ese middleware:

```javascript
const app = express();
app.use(express.json()); // permite leer cuerpos JSON (equivale a request.json en Flask)
```

Sin el, `req.body` llega vacio y toda petición con cuerpo falla.

### Conexión a MySQL

| Flask-MySQLdb | mysql2 |
|---|---|
| `mysql = MySQL(app)` y después `app.config['MYSQL_...']` | `mysql.createPool({ host, user, password, database })` |
| `mysql.connection.cursor()` | `pool.query(...)` |
| `mysql.connection.commit()` | Automático: cada consulta ya confirma |
| `cur.execute(sql, (params,))` | `pool.query(sql, [params])` |

El código de Node importa el modo `promise`:

```javascript
const mysql = require('mysql2/promise');
```

Por eso las consultas usan `await` y devuelven `[rows]`, un arreglo con las filas y metadatos.

Diferencia útil para la práctica: mysql2 confirma cada sentencia por su cuenta, así que **no existe el `commit()` explicito** de la Parte 3. El commit tampoco es la razon de la rareza 2, que ocurre antes del `UPDATE`, pero es una diferencia real entre los dos códigos.

## Rutas

El único cambio de sintaxis es la declaración: Flask recibe el id en la ruta con un conversor `<int:book_id>`, Express lo toma de `req.params`.

| Flask | Express |
|---|---|
| `@app.route('/books/<int:book_id>', methods=['GET'])` | `app.get('/books/:id', async (req, res) => {...})` |
| `book_id` (argumento de la función) | `req.params.id` |
| `jsonify({'book': book[0]})` | `res.json({ book: rows[0] })` |
| `abort(404)` | `res.status(404).json({ error: 'Not found' })` |
| `return jsonify(...), 201` | `res.status(201).json(...)` |
| `app.run(debug=True)` | `app.listen(3000, '0.0.0.0', ...)` |

## Arranque

```bash
# (dentro de la VM) Entra a la carpeta del Desafio.
# DECIR: "La versión en JavaScript del mismo contrato."
cd /home/vagrant/app/desafio-node
```

```bash
# (dentro de la VM) Arranca el servidor de Express en el puerto 3000.
# OJO: package.json no define un script "start", hay que ejecutar el archivo.
# DECIR: "Levanto Express en el 3000. Además escucha en 0.0.0.0, así que también lo
# alcanzo desde Windows, a diferencia de Flask."
node server.js
```

Salida esperada:

```
API Node escuchando en http://0.0.0.0:3000
```

### El puerto y las dos APIs a la vez

| Servicio | Puerto | Puede correr junto a |
|---|---|---|
| Parte 1 (Flask) | 5000 | Desafio |
| Parte 3 (Flask) | 5000 | Desafio |
| Desafio (Node) | 3000 | Parte 1 o Parte 3 |

La Parte 1 y la Parte 3 no pueden coexistir entre sí, pero cualquiera de las dos sí con Node. Por eso el Desafio es el escenario ideal para la demostración de datos compartidos.

## Las mismas cinco consultas

```bash
# (dentro de la VM) Listado. Respuesta identica a la de Flask.
# DECIR: "El listado es el mismo."
curl -i http://localhost:3000/books
```

```bash
# (dentro de la VM) Un libro por id.
curl -i http://localhost:3000/books/2
```

```bash
# (dentro de la VM) Crea un libro. Esta vez la respuesta SI trae el id.
# DECIR: "Aqui recibo el id, porque mysql2 lo entrega en result.insertId. Primera mejora."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Rayuela","description":"Novela","author":"Cortazar"}' http://localhost:3000/books
```

```bash
# (dentro de la VM) Actualiza el autor y devuelve el libro YA actualizado.
# DECIR: "Y el PUT devuelve el estado final, no el anterior. Segunda mejora."
curl -i -X PUT -H "Content-Type: application/json" -d '{"author":"Jorgito"}' http://localhost:3000/books/2
```

```bash
# (dentro de la VM) El id 99 no existe y aqui si responde 404, con cuerpo JSON.
# DECIR: "Y un id inexistente da 404 en vez de 500. Tercera mejora."
curl -i http://localhost:3000/books/99
```

Respuesta del 404:

```json
{"error": "Not found"}
```

## Las cuatro mejoras sobre la línea base de Flask

| Mejora | Parte 3 (Flask) | Desafio (Node) |
|---|---|---|
| 1. Id inexistente | 500 por `IndexError` | 404 con `{"error":"Not found"}` |
| 2. Respuesta del `PUT` | El libro **anterior** al cambio | El libro **actualizado** |
| 3. Respuesta del `POST` | El cuerpo enviado, sin `id` | El recurso creado, con `id` |
| 4. SQL | Mezcla de concatenación y marcadores | Marcadores `?` en todas las consultas |

### Mejora 1: validar antes de indexar

```javascript
app.get('/books/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM books WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
  res.json({ book: rows[0] });
});
```

Una línea: `if (rows.length === 0)`. Es exactamente la validación que le falta a `get_book()` en `app/parte3-mysql/apirest_mysql.py`, y la misma que sí tiene la Parte 1 con `if len(book) == 0: abort(404)`.

### Mejora 2: el `PUT` construye el objeto final

```javascript
const book = { ...rows[0], ...req.body, id: rows[0].id };
```

El orden de las partes importa:

| Parte del objeto | Efecto |
|---|---|
| `...rows[0]` | Valores actuales, tomados del `SELECT` |
| `...req.body` | Sobrescriben con lo que llegó en la petición |
| `id: rows[0].id` | El id nunca cambia, aunque venga en el cuerpo |

El resultado es un objeto con el estado final, y es ese objeto el que se responde. En la Parte 3, en cambio, se responde el diccionario leído **antes** del `UPDATE`.

### Mejora 3: el `POST` devuelve el id generado

```javascript
const [result] = await pool.query(
  'INSERT INTO books (title, description, author) VALUES (?, ?, ?)',
  [title, description, author]
);
res.status(201).json({ book: { id: result.insertId, title, description, author } });
```

`result.insertId` es el valor que MySQL asigno con `AUTO_INCREMENT`. La Parte 3 ejecuta el mismo `INSERT` pero devuelve `request.json`, o sea, lo que el cliente mando: por eso nunca puede incluir el id.

La Parte 1 sí lo puede, pero por otra razon: el id lo genero el propio código con `books[-1]['id'] + 1`, así que ya lo tenía a mano antes de insertar.

### Mejora 4: consultas parametrizadas en todas partes

| Parte 3 | Desafio |
|---|---|
| `"SELECT * from books WHERE id="+str(book_id)` | `'SELECT * FROM books WHERE id = ?', [req.params.id]` |
| `"DELETE FROM books WHERE id="+str(book_id)` | `'DELETE FROM books WHERE id = ?', [req.params.id]` |
| `"UPDATE books ... WHERE id="+str(book_id)` | `'UPDATE books ... WHERE id = ?', [book.id]` |
| `VALUES(%s,%s,%s)` con tupla | `VALUES (?, ?, ?)` con arreglo |

En la Parte 3 el `id` se concatena, pero la ruta de Flask es `/books/<int:book_id>` y el conversor `int` rechaza cualquier valor no entero antes de que la función corra, así que hoy no es explotable. En Node, el id llega como `req.params.id`, que es texto sin validar, y por eso los marcadores no son opcionales: son la razon de que sean obligatorios.

## La demostración entre los dos lenguajes

Es el cierre de la práctica. Deja las dos APIs vivas al mismo tiempo, cada una en su terminal:

```bash
# (dentro de la VM, terminal 1) Parte 3 en el puerto 5000.
python3 apirest_mysql.py
```

```bash
# (dentro de la VM, terminal 2) Desafio en el puerto 3000.
node server.js
```

Es posible porque usan puertos distintos. Ahora escribe por un lado y lee por el otro:

```bash
# (dentro de la VM) Creo un libro por la API de Node.
# DECIR: "Creo un libro por Node, en el puerto 3000."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Desde Node","description":"Insertado a mano","author":"Juan"}' http://localhost:3000/books
```

```bash
# (dentro de la VM) Lo leo por Flask, en el puerto 5000. Aparece sin traduccion alguna.
# DECIR: "Ahora lo leo con Flask, sin haber pasado por Node. Aparece igual, porque las dos
# APIs apuntan a la misma tabla myflaskapp."
curl -i http://localhost:5000/books
```

Y lo mismo al revés, para mostrar que no es una cuestión de orden:

```bash
# (dentro de la VM) Creo un libro por Flask.
# DECIR: "Y ahora al revés: creó por Flask."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Desde Flask","description":"Insertado por Python","author":"Juan"}' http://localhost:5000/books
```

```bash
# (dentro de la VM) Y lo leo por Node.
curl -i http://localhost:3000/books
```

Limpieza, para no dejar datos de prueba en la base:

```bash
# (dentro de la VM) Borra los libros creados en la demostracion.
sudo mysql -u root -proot myflaskapp -e 'DELETE FROM books WHERE title IN ("Desde Node","Desde Flask");'
```

## La prueba de que el id lo genera MySQL

La Parte 3 y el Desafio comparten el mismo `AUTO_INCREMENT`. Con Node parado y la Parte 3 corriendo:

```bash
# (dentro de la VM) Inserto con SQL sin pasar por ninguna API.
sudo mysql -u root -proot myflaskapp -e 'INSERT INTO books VALUES(NULL,"Desde SQL","Insertado a mano","Juan");'
```

```bash
# (dentro de la VM) Lo leo por API y MySQL le asigno el id siguiente.
curl -i http://localhost:5000/books
```

El id que aparece lo eligió MySQL, no ningún código de Python ni de JavaScript.

```bash
# (dentro de la VM) Limpieza: borro el libro de la prueba.
sudo mysql -u root -proot myflaskapp -e 'DELETE FROM books WHERE title="Desde SQL";'
```

## El argumento de cierre

> Que decir: "La misma API, dos lenguajes, cuatro capas distintas y un solo contrato. Cuando hago un `GET /books` no se quien respondio: no se si fue Python o JavaScript, no se si fue Flask o Express, no se si fue mysqlclient o mysql2. Y eso es exactamente lo que quiero. Si regalo el código, regalo una solución. Si regalo el contrato, regalo la especificación, y cualquier equipo lo implementa en el lenguaje que necesite. En esta práctica los datos cambian de lugar cuatro veces: la RAM, la nube, el disco, y el disco desde otro lenguaje. Lo único que no cambio es el contrato. Esa es la razon de ser del ejercicio."

## Lo que hay que saber explicar

| Tema | Que decir |
|---|---|
| Por que dos lenguajes | Para demostrar que el contrato es el entregable, no el framework |
| `express.json()` | Es el equivalente a que `request.json` funcione en Flask |
| `mysql2` pool | Equivale a la conexión de Flask-MySQLdb, pero confirma sola |
| `req.params.id` | El equivalente de `<int:book_id>`, pero llega como texto |
| Puerto 3000 | Permite correr junto a la Parte 1 o la Parte 3 |
| 404 correcto | Una validación de una línea: `if (rows.length === 0)` |
| `PUT` corregido | `{ ...rows[0], ...req.body }` construye el estado final |
| `POST` con id | `result.insertId` de mysql2 |
| Marcadores `?` | Obligatorios, porque en Node el id no está validado |
| Datos compartidos | Las dos APIs leen y escriben `myflaskapp.books` |

Si algo falla durante la demostración, el detalle está en [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
