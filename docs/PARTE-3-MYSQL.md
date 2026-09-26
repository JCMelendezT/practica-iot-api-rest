# Parte 3: MySQL

## Qué demuestra

Que mover el dato de la RAM a un **disco** convierte la API en un sistema persistente. Los datos sobreviven a que se detenga el proceso y a que se apague la máquina virtual.

Es la misma API de la Parte 1, con una única diferencia: cada vez que el código lee o escribe, lo hace con SQL contra MySQL.

## `init.sql`: la base y la tabla

Archivo: `app/parte3-mysql/init.sql`. Se importa durante el aprovisionamiento.

```sql
CREATE DATABASE IF NOT EXISTS myflaskapp;
USE myflaskapp;

DROP TABLE IF EXISTS books;

CREATE TABLE books (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title varchar(255),
    description varchar(255),
    author varchar(255)
);

INSERT INTO books (id, title, description, author) VALUES
    (NULL, "La hojarasca",    "Interesante", "Gabo"),
    (NULL, "El principito",   "Brillante",   "Antoine de Saint");
```

| Detalle | Valor |
|---|---|
| Base de datos | `myflaskapp` |
| Tabla | `books` |
| Servidor | MySQL 8.0.46 |
| Usuario | `root`@`localhost`, contraseña `root` |
| Plugin de autenticación | `caching_sha2_password` |
| Listen | `bind-address = 0.0.0.0` |
| Datos iniciales | 2 filas |

### Que hace `AUTO_INCREMENT`

La columna `id` está declarada `AUTO_INCREMENT`. Eso significa que **MySQL** lleva la cuenta, no el código de la aplicación.

En el `INSERT` se escribe `id` en `NULL` a propósito, con un comentario en el propio archivo que lo explica. MySQL ve el `NULL`, toma el siguiente valor de su contador y lo asigna:

| Momento | Filas | Valores de `id` | Siguiente id |
|---|---|---|---|
| Tras `init.sql` | 2 | 1, 2 | 3 |
| Tras un `POST` | 3 | 1, 2, 3 | 4 |
| Tras un `DELETE` | 2 | 1, 2 | 4 |

El contador **no se reinicia** cuando borra filas: sigue avanzando. Solo se reinicia si la tabla se destruye, que es justo lo que hace el `DROP TABLE IF EXISTS books` de `init.sql`.

Comparación con la Parte 1:

| | Parte 1 | Parte 3 |
|---|---|---|
| Quien asigna el id | El código, con `books[-1]['id'] + 1` | MySQL, con `AUTO_INCREMENT` |
| Dónde vive | En la RAM del proceso | En el disco de la VM |
| El `POST` puede devolver el id | Sí, ya lo conoce | No, tendría que volver a consultarlo |

Esa última fila explica una diferencia observable en el contrato: el `POST` de la Parte 3 devuelve el cuerpo que le mandaron, sin el `id`.

### `init.sql` es un reset

El archivo ejecuta `DROP TABLE IF EXISTS books` y vuelve a sembrar las dos filas. Por eso **volver a correr el aprovisionamiento borra los datos**:

| Comando | Que hace | Pierdo los datos |
|---|---|---|
| `vagrant halt` + `vagrant up` | Apaga y enciende la VM | No |
| `vagrant up` por segunda vez | No reprovisiona | No |
| `vagrant provision` | Vuelve a correr el paso 02, que importa `init.sql` | **Si** |
| `vagrant up --provision` | Igual que lo anterior | **Si** |
| `vagrant destroy` | Borra el disco de la VM | **Si**, y hay que reprovisionar |

## Configuración de la conexión

En `app/parte3-mysql/apirest_mysql.py` la conexión se declara en el propio archivo:

```python
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = 'root'
app.config['MYSQL_DB'] = 'myflaskapp'
app.config['MYSQL_CURSORCLASS'] = 'DictCursor'
```

`DictCursor` es lo que hace que las filas lleguen como diccionarios de Python en vez de tuplas, que es lo que espera `jsonify`.

> Que decir: "La conexión se configura en cinco líneas. Lo relevante para la práctica es `DictCursor`: con un cursor normal, MySQL devuelve tuplas y la respuesta JSON sería una lista de listas en vez de una lista de objetos."

## Arranque

La Parte 1 y la Parte 3 usan el puerto 5000, así que no pueden correr a la vez.

```bash
# (dentro de la VM) Detener la Parte 1 con Ctrl+C en su terminal.
```

```bash
# (dentro de la VM) Entra a la carpeta de la Parte 3.
cd /home/vagrant/app/parte3-mysql
```

```bash
# (dentro de la VM) Arranca la API contra MySQL.
# DECIR: "Es el mismo contrato REST que la Parte 1. Lo único que cambió es de dónde salen los datos."
python3 apirest_mysql.py
```

## Consola de MySQL

Consola interactiva:

```bash
# (dentro de la VM) Abre la consola de MySQL sobre la base de la practica.
# DECIR: "Entro por otra puerta al mismo dato."
sudo mysql -u root -proot myflaskapp
```

```sql
-- Ve toda la tabla, incluido el id que asigno AUTO_INCREMENT.
SELECT * FROM books;
```

```sql
-- Ve como quedo definida la tabla y cuanto vale el siguiente id de AUTO_INCREMENT.
SHOW CREATE TABLE books;
SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='myflaskapp' AND TABLE_NAME='books';
```

```sql
-- Sale de la consola.
exit;
```

Atajo de una línea, sin abrir la consola:

```bash
# (dentro de la VM) Consulta directa, equivalente a abrir la consola y escribir el SELECT.
sudo mysql -u root -proot myflaskapp -e "SELECT * FROM books;"
```

Dentro de la VM, `mysql -u root -proot myflaskapp` funciona igual sin `sudo`, porque el usuario `root@localhost` existe con contraseña. El `sudo` se usa en los scripts de aprovisionamiento por si MySQL quedara con `auth_socket`.

## Comportamiento verificado de los endpoints

| Caso | Respuesta |
|---|---|
| `GET /books` | 200, con los 2 libros semilla |
| `GET /books/2` | 200 |
| `GET /books/99` (inexistente) | **500**, no 404 |
| `POST /books` | 201, **devuelve el cuerpo enviado, sin `id`** |
| `POST /books` sin `title` | 400 |
| `PUT /books/2` | 200, devuelve el libro **anterior** al cambio |
| `PUT /books/99` (inexistente) | **500**, no 404 |
| `DELETE /books/<id>` | 200 `{"result": true}` |
| `GET` sobre un id borrado | **500**, no 404 |

Las cinco respuestas correctas son identicas a las de la Parte 1. Las cuatro marcadas son el objeto de la Parte 3.

## Las tres rarezas deliberadas

No son descuidos. Son la **línea base** que el Desafio en Node viene a mejorar. Están documentadas aquí para poder explicarlas, no para disimularlas.

### Rareza 1: 500 en vez de 404

`get_book()` no comprueba que la consulta haya devuelto algo:

```python
cur.execute("SELECT * from books WHERE id="+str(book_id))
book = cur.fetchall()
return jsonify({'book': book[0]})
```

Con un id inexistente, `fetchall()` devuelve una lista vacía y `book[0]` lanza `IndexError`. Flask no tiene un manejador para esa excepción, así que responde con su página genérica de 500.

El contraste con la Parte 1 es el punto de la demostración:

| Versión | Validación | Respuesta |
|---|---|---|
| Parte 1 | `if len(book) == 0: abort(404)` | 404 |
| Parte 3 | ninguna | 500 |
| Desafio (Node) | `if (rows.length === 0) return res.status(404)` | 404 |

El mismo problema aparece en `update_book()` y, por consecuencia, en un `GET` posterior a un `DELETE`.

> Que decir: "En esta versión, pedir un libro que no existe devuelve 500 en vez de 404. La causa es que el código hace `fetchall` y luego toma `book[0]` sin validar que haya resultados, entonces un id inexistente produce un `IndexError` y Flask responde con su error genérico. No lo presento como un error mio: es la línea base, y el Desafio consiste en corregirlo."

### Rareza 2: el `PUT` devuelve el libro anterior al cambio

```python
cur.execute("SELECT * FROM books where id="+str(book_id))
book = cur.fetchall()
print(book[0])
title = request.json.get('title', book[0]['title'])
description = request.json.get('description', book[0]['description'])
author = request.json.get('author', book[0]['author'])
cur.execute("UPDATE books SET title =%s, description =%s ,author= %s WHERE id=%s",(title,description,author,book_id))
mysql.connection.commit()
return jsonify({'book': book[0]})
```

El `SELECT` ocurre **antes** del `UPDATE`. Cuando la función responde, `book[0]` sigue siendo el diccionario que se leyo del principio, con los valores anteriores. El `UPDATE` sí se ejecutó y sí se confirmó con `commit`, así que el cambio **si** quedo en el disco: lo que miente es la respuesta.

| Versión | Que devuelve el `PUT` |
|---|---|
| Parte 1 | El libro ya actualizado |
| Parte 3 | El libro de antes del cambio |
| Desafio (Node) | El libro ya actualizado |

La forma de demostrarlo es hacer el `PUT` y después consultar la tabla por SQL: los dos caminos muestran valores distintos.

### Rareza 3: el `DELETE` siempre responde `true`

```python
cur.execute("DELETE FROM books WHERE id="+str(book_id))
mysql.connection.commit()
return jsonify({'result': True})
```

El código no mira cuantas filas elimino el `DELETE`. Borro una fila, o cero, y la respuesta es siempre la misma.

| Versión | `DELETE` de un id existente | `DELETE` de un id inexistente |
|---|---|---|
| Parte 1 | 200 `{"result": true}` | 404 |
| Parte 3 | 200 `{"result": true}` | 200 `{"result": true}` |
| Desafio (Node) | 200 `{"result": true}` | 200 `{"result": true}` |

## La semántica de actualización parcial del `PUT`

El `PUT` no reemplaza el recurso completo. Hace un `SELECT` primero y luego usa cada campo recibido, con el valor guardado como respaldo:

```python
title = request.json.get('title', book[0]['title'])
```

Eso significa que:

| Petición | `title` | `description` | `author` |
|---|---|---|---|
| `{"author": "Jorgito"}` | sin cambio | sin cambio | `Jorgito` |
| `{"title": "X", "author": "Jorgito"}` | `X` | sin cambio | `Jorgito` |

Para cambiar un campo a cadena vacía hay que enviarlo explícitamente como `""`, porque `get` no distingue entre "ausente" y "vacio".

## SQL concatenado frente a consultas parametrizadas

En `get_book()`, `update_book()` y `delete_book()`, el id se mete en el SQL concatenando cadenas:

```python
cur.execute("SELECT * from books WHERE id="+str(book_id))
```

En el resto de las consultas sí se usan marcadores:

```python
cur.execute("INSERT INTO books(title,description,author) VALUES(%s,%s,%s)",(title,description,author))
```

| Enfoque | Que hace | Ventaja | Riesgo |
|---|---|---|---|
| Concatenar `"WHERE id="+str(book_id)` | Arma el texto del SQL en Python | Ninguna | Si el valor no fuera un entero controlado, se podría inyectar SQL |
| Marcadores `%s` | El driver escapa los valores | El driver se encarga del escapado | Ninguno |

Estado real hoy: la ruta de Flask es `/books/<int:book_id>`, y el conversor `int` **rechaza** cualquier valor no entero antes de que la función se ejecute. Así que la concatenación no es explotable en este código. Aun así, es una mala costumbre, y la versión en Node la corrige usando marcadores `?` en todas las consultas:

```javascript
const [rows] = await pool.query('SELECT * FROM books WHERE id = ?', [req.params.id]);
```

> Que decir: "Aca hay dos estilos. En los INSERT sí uso marcadores, pero en los SELECT, UPDATE y DELETE concateno el id. Hoy eso no es explotable, porque el conversor `int` de Flask rechaza cualquier cosa que no sea un entero antes de llegar al código. Pero el equipo de Node si usa marcadores en todas las consultas, y esa es la forma correcta: no delegar el escapado en el tipo del dato."

## La demostración de persistencia

Es la prueba que cierra la parte. Se hace con la API y la consola de MySQL abiertos.

### 4.1 Insertar por SQL, leer por API

```bash
# (dentro de la VM) Escribe un libro directo en la base, sin pasar por la API.
# DECIR: "Este camino no existe en la Parte 1, porque alla no hay base de datos."
sudo mysql -u root -proot myflaskapp -e 'INSERT INTO books VALUES(NULL,"Desde SQL","Insertado a mano","Juan");'
```

```bash
# (dentro de la VM) Lo lee por la API y aparece.
# DECIR: "Aparece. La API y la consola son dos puertas al mismo dato."
curl -i http://localhost:5000/books
```

### 4.2 Sobrevivir al reinicio de la VM

Detener la API con `Ctrl+C` y después, desde el host:

```bash
# (host) Apaga la VM. No borra el disco.
vagrant halt
```

```bash
# (host) Comprueba que quedo apagada, no destruida.
vagrant status
```

```bash
# (host) Vuelve a encender. No reprovisiona, asi que no toca los datos.
vagrant up
```

```bash
# (dentro de la VM) MySQL levanta solo, porque el paso 02 lo habilito con systemctl enable.
systemctl is-active mysql
```

```bash
# (dentro de la VM) Los datos siguen ahi.
sudo mysql -u root -proot myflaskapp -e "SELECT * FROM books;"
```

Respuesta corta, memorizada:

> "Los datos sobreviven porque MySQL escribe en el disco de la máquina virtual, no en la memoria del proceso. `halt` apaga la VM sin borrar el disco, y el aprovisionamiento solo corre en el primer `vagrant up`. Lo único que borra el disco es `vagrant destroy`."

Y la advertencia, porque es la confusión más común del laboratorio:

> "Cuidado con `vagrant provision`: vuelve a correr el paso 02, y `init.sql` hace `DROP TABLE IF EXISTS books`. Es un reset total. Para demostrar persistencia se usa `halt` y `up`, que no reprovisionan."

## Lo que hay que saber explicar

| Tema | Que decir |
|---|---|
| Persistencia | El dato está en el disco de la VM, no en la RAM del proceso |
| `AUTO_INCREMENT` | MySQL lleva la cuenta del id; el `INSERT` pone `NULL` a propósito |
| `init.sql` | Crea la base, la tabla y la siembra; además hace `DROP TABLE`, así que reprovisionar resetea |
| `DictCursor` | Sin el, las filas llegan como tuplas y el JSON no tendría la forma esperada |
| Rareza 1 | `book[0]` sin validar la lista vacía produce `IndexError` y por eso 500 en vez de 404 |
| Rareza 2 | El `SELECT` ocurre antes del `UPDATE`, así que la respuesta es el estado anterior |
| Rareza 3 | El `DELETE` no mira cuantas filas borro y siempre responde `true` |
| `PUT` parcial | Cada campo ausente conserva su valor guardado |
| SQL concatenado | Hoy no es explotable por el conversor `int` de Flask, pero es mala costumbre |
| Reinicio | `halt`/`up` conserva; `provision` resetea; `destroy` borra el disco |

## Siguiente paso

La Parte 3 quedo con cuatro comportamientos que no son ideales. La Parte siguiente reimplementa la misma API en JavaScript y los corrige.

Continua con [DESAFIO-NODE.md](DESAFIO-NODE.md).
