# Chuleta de sustentación

Todo lo que necesitas para la defensa oral, en orden, listo para copiar y pegar. Cada comando lleva un comentario que dice **que hace** y **que decir en voz alta**.

Leyenda de los comandos:

- `(host)`: se ejecuta en Windows, macOS o Linux, en la carpeta del repositorio.
- `(dentro de la VM)`: se ejecuta después de `vagrant ssh servidorRest`.

---

## 0. Antes de empezar: dos terminales

Un servidor en primer plano ocupa la terminal. No se puede escribir en una terminal que está bloqueada por un proceso corriendo. Por eso hacen falta dos sesiones de SSH.

Las dos terminales son **dentro de la VM**: las abres con `vagrant ssh servidorRest`. La Terminal 2 es, entonces, el lugar donde se escribe **todos** los `curl` y todos los `mysql` de esta chuleta, y su `localhost` es el de la VM. Ninguno de esos comandos se escribe en Windows, y desde Windows no se pueden copiar y pegar tal cual.

| Terminal | Que hace | Estado |
|---|---|---|
| Terminal 1 | Corre el servidor | Queda imprimiendo logs, "trabada" a propósito |
| Terminal 2 | Ejecuta `curl` y `mysql` | Libre para demostrar |

Las dos se abren igual, desde el host:

```bash
# (host) Primera sesion: aca va a correr el servidor.
vagrant ssh servidorRest
```

```bash
# (host) Segunda sesion, en otra ventana de terminal: aca se demuestra.
vagrant ssh servidorRest
```

> Que digo: "Abro dos sesiones de SSH porque el servidor corre en primer plano y bloquea la terminal. En la primera queda registrado cada request; en la segunda hago las consultas, para que se vea la respuesta y el log al mismo tiempo."

---

## 1. Parte 1: memoria

Terminal 1 arranca el servidor. Terminal 2 demuestra.

```bash
# (dentro de la VM) Entra a la carpeta de la Parte 1.
cd /home/vagrant/app/parte1-memoria
```

```bash
# (dentro de la VM) Arranca Flask en el puerto 5000.
# DECIR: "Arranco la Parte 1. Los datos viven en una lista de Python dentro del proceso."
python3 apirest.py
```

### 1.1 Las cinco consultas

```bash
# (dentro de la VM) Trae los 2 libros semilla.
# DECIR: "Empiezo por el listado completo."
curl -i http://localhost:5000/books
```

```bash
# (dentro de la VM) Trae el libro con id 2.
# DECIR: "Ahora pido uno solo por id."
curl -i http://localhost:5000/books/2
```

```bash
# (dentro de la VM) Crea un libro. La respuesta trae el id generado.
# DECIR: "Creo un libro. El id lo genera el código con books[-1]['id'] + 1, y por eso la respuesta lo incluye."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Cien anos de soledad","description":"Obra maxima","author":"Garcia Marquez"}' http://localhost:5000/books
```

```bash
# (dentro de la VM) Actualiza solo el autor del libro 2: es una actualizacion parcial.
# DECIR: "El PUT es parcial. Solo envío el autor, y el título y la descripción conservan su valor."
curl -i -X PUT -H "Content-Type: application/json" -d '{"author":"Jorgito"}' http://localhost:5000/books/2
```

```bash
# (dentro de la VM) Sin title la API responde 400.
# DECIR: "El title es obligatorio; sin el responde 400."
curl -i -X POST -H "Content-Type: application/json" -d '{"author":"Sin titulo"}' http://localhost:5000/books
```

### 1.2 Prueba del 404

```bash
# (dentro de la VM) El id 99 no existe, y esta version responde 404.
# DECIR: "Aquí se ve una de las diferencias con la Parte 3: esta versión sí valida la lista vacía y responde 404."
curl -i http://localhost:5000/books/99
```

### 1.3 Prueba de la volatilidad: el dato más importante de la parte

```bash
# (dentro de la VM, en la terminal 1) Con el servidor en primer plano, presiona Ctrl+C
# para detenerlo. Con debug=True puede pedirlo dos veces.
# DECIR: "Ahora detengo el servidor. No borre nada: solo dejo de existir el proceso."
```

Luego vuelve a arrancar y consulta de nuevo:

```bash
# (dentro de la VM, terminal 1) Vuelve a arrancar la misma aplicacion.
python3 apirest.py
```

```bash
# (dentro de la VM, terminal 2) El libro que cree en 1.1 ya no esta.
# DECIR: "El libro que cree desaparecio. La lista vivia en la RAM del proceso, y al
# terminar el proceso se libero. Ningun disco fue escrito. Esta es la definicion de
# dato volatil."
curl -i http://localhost:5000/books
```

---

## 2. Parte 2: Ubidots

No hay servidor local: este script es un **cliente** que publica sensores en la nube de Ubidots. Ubidots es un servicio de pago con un plan STEM limitado, así que la cuota diaria es real.

### 2.1 Configurar el token

```bash
# (dentro de la VM) Exporta tu token personal de Ubidots en ESTA terminal.
# DECIR: "El token es una credencial personal. Va en una variable de entorno y nunca
# en el codigo ni en el repositorio."
export UBIDOTS_TOKEN=BBUS-pega-aqui-tu-token
```

```bash
# (dentro de la VM) Verifica que la variable quedo cargada, sin imprimir el valor completo.
# DECIR: "Compruebo que la variable existe, sin exponerla."
test -n "$UBIDOTS_TOKEN" && echo "token cargado"
```

### 2.2 Correr el script de sensores

```bash
# (dentro de la VM) Entra a la carpeta de la Parte 2.
cd /home/vagrant/app/parte2-ubidots
```

```bash
# (dentro de la VM) Corre el cliente. Envia cada 10 segundos, sin parar.
# DECIR: "El script genera cinco variables simuladas y las envia cada 10 segundos a
# industrial.api.ubidots.com. Lo corro un minuto y lo freno con Ctrl+C."
python3 testUbidots.py
```

Deja correr entre 60 y 120 segundos y presiona `Ctrl+C`. Cada vuelta imprime `[INFO] request made properly, your device is updated`.

Si no exportaste el token, el script imprime en `stderr` y termina con código de salida 1:

```
[ERROR] Falta la variable de entorno UBIDOTS_TOKEN.
[ERROR] Configurala en esta terminal con:
[ERROR]     export UBIDOTS_TOKEN=BBUS-tu-token-completo
[ERROR] Mira docs/PARTE-2-UBIDOTS.md para como obtener el token.
```

> Que digo: "Si falta el token, el script falla rapido y con un mensaje útil, en vez de repetir cinco veces un 401 y hacerme creer que el internet está roto."

### 2.3 Enviar un dato a mano: las dos formas de autenticación

Forma recomendada, token en la cabecera:

```bash
# (dentro de la VM) Envia un valor unico con el token en la cabecera X-Auth-Token.
# DECIR: "Esta es la forma correcta: el token viaja en una cabecera y no queda en la
# URL ni en el historial del shell."
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine" -H "X-Auth-Token: $UBIDOTS_TOKEN" -H "Content-Type: application/json" -d '{"temperature": 25}'
```

Forma alternativa, token en la query string:

```bash
# (dentro de la VM) La misma peticion con el token como parametro ?token=.
# DECIR: "Esta forma también funciona, y hay que entrecomillar la URL porque el
# ampersand lo interpretaria el shell. La diferencia es que el token queda escrito
# en la linea de comandos y en los logs del servidor."
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine?token=$UBIDOTS_TOKEN" -H "Content-Type: application/json" -d '{"temperature": 25}'
```

### 2.4 Leer el último valor

```bash
# (dentro de la VM) El sufijo lv significa last value: devuelve solo el dato mas reciente.
# DECIR: "Asi leo de vuelta lo que el sensor acaba de publicar."
curl -s -H "X-Auth-Token: $UBIDOTS_TOKEN" "https://industrial.api.ubidots.com/api/v1.6/devices/machine/temperature/lv"
```

### 2.5 Disparar la alerta por correo

```bash
# (dentro de la VM) Envia 45 grados, por encima del umbral de 40.
# DECIR: "La regla de alerta de Ubidots dispara cuando la temperatura supera 40. Le
# mando 45 a proposito y espero el correo. No tengo que esperar a que un sensor aleatorio
# pase de 40, que puede no pasar nunca en una demostracion."
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine" -H "X-Auth-Token: $UBIDOTS_TOKEN" -H "Content-Type: application/json" -d '{"temperature": 45}'
```

### 2.6 Verlo en el dashboard

> Que digo: "En la consola de Ubidots, en el dispositivo `machine`, veo los widgets con el historico de las cinco variables y el punto en el mapa, porque `position` se manda con contexto GPS. Esta es la parte de la práctica donde los datos dejan de estar en mi computadora y quedan en un servicio externo."

---

## 3. Parte 3: MySQL

Primero detener la Parte 1: ambas usan el puerto 5000.

### 3.1 Arrancar la API

```bash
# (dentro de la VM) Detener la Parte 1 con Ctrl+C en la terminal 1.
# DECIR: "Las partes 1 y 3 usan el puerto 5000, asi que no pueden correr juntas."
```

```bash
# (dentro de la VM) Entra a la carpeta de la Parte 3.
cd /home/vagrant/app/parte3-mysql
```

```bash
# (dentro de la VM) Arranca la misma API, ahora contra MySQL.
# DECIR: "Es el mismo contrato REST. Lo único que cambió es de dónde vienen los datos."
python3 apirest_mysql.py
```

### 3.2 Mirar la base de datos

Consola interactiva:

```bash
# (dentro de la VM) Abre la consola de MySQL sobre la base de la practica.
# DECIR: "Conecto como root, que es el único usuario que existe, y entró a myflaskapp."
sudo mysql -u root -proot myflaskapp
```

```sql
-- Muestra toda la tabla, con el id generado por AUTO_INCREMENT.
SELECT * FROM books;
```

```sql
-- Muestra como esta definida la tabla y cuanto vale el siguiente id de AUTO_INCREMENT.
SHOW CREATE TABLE books;
SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='myflaskapp' AND TABLE_NAME='books';
```

```sql
-- Sale de la consola.
exit
```

Atajo de una línea, sin entrar a la consola:

```bash
# (dentro de la VM) Consulta directa, equivalente a abrir la consola y escribir el SELECT.
# DECIR: "También puedo consultar sin entrar a la consola, con la opción -e."
sudo mysql -u root -proot myflaskapp -e "SELECT * FROM books;"
```

### 3.3 Las cinco consultas, cada una con su `SELECT`

```bash
# (dentro de la VM) Listado. 200 con los 2 libros semilla.
# DECIR: "Los mismos dos libros semilla."
curl -i http://localhost:5000/books
```

```bash
# (dentro de la VM) Un libro por id.
curl -i http://localhost:5000/books/2
```

```bash
# (dentro de la VM) Crea un libro. OJO: la respuesta NO trae id.
# DECIR: "La respuesta es 201, pero noten que devuelve el cuerpo que yo mande y no el
# id. La razon es que MySQL genera el id con AUTO_INCREMENT y el codigo nunca vuelve
# a leerlo."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Pedro Paramo","description":"Clasico","author":"Juan Rulfo"}' http://localhost:5000/books
```

```bash
# (dentro de la VM) Ahora si, desde SQL, compruebo que el INSERT si llego al disco.
# DECIR: "Inserto por la API, pero verifico por el lado de la base. Si aparece, el dato
# esta en MySQL, no en la memoria del proceso."
sudo mysql -u root -proot myflaskapp -e "SELECT * FROM books;"
```

```bash
# (dentro de la VM) Actualiza solo el autor. OJO: devuelve el libro ANTERIOR al cambio.
# DECIR: "El PUT es una actualizacion parcial: hace un SELECT primero y cada campo que no
# mando conserva su valor guardado. Pero noten que la respuesta es el libro que leyo
# ANTES del UPDATE, no el que quedo despues. Es una de las tres rarezas de esta version."
curl -i -X PUT -H "Content-Type: application/json" -d '{"author":"Jorgito"}' http://localhost:5000/books/2
```

```bash
# (dentro de la VM) Vuelvo a consultar por SQL para ver el valor realmente guardado.
# DECIR: "Por la API parecia que no habia cambiado, pero el disco si. Repito la consulta
# para verlo."
sudo mysql -u root -proot myflaskapp -e "SELECT * FROM books WHERE id=2;"
```

```bash
# (dentro de la VM) El id 99 no existe y esta version responde 500, no 404.
# DECIR: "Esta es la rareza principal: get_book hace fetchall y luego toma book[0] sin
# validar que haya elementos, entonces un id inexistente lanza IndexError y Flask
# responde 500. No lo escondo: es la linea base que el Desafio viene a mejorar."
curl -i http://localhost:5000/books/99
```

```bash
# (dentro de la VM) DELETE responde siempre {"result": true}, borre filas o no.
# DECIR: "El DELETE no mira cuantas filas borro, siempre responde que si."
curl -i -X DELETE http://localhost:5000/books/1
```

### 3.4 Demo: insertar por SQL, leer por API

```bash
# (dentro de la VM) Inserto un libro escribiendolo directo en SQL, sin pasar por la API.
# DECIR: "Ahora escribo en la base sin usar la API. Este camino no existe en la Parte 1,
# porque alla no hay base de datos."
sudo mysql -u root -proot myflaskapp -e 'INSERT INTO books VALUES(NULL,"Desde SQL","Insertado a mano","Juan");'
```

```bash
# (dentro de la VM) Y ahora lo leo por la API. Esta vez aparece.
# DECIR: "Leo por la API y el libro que escribi en SQL aparece. Pruebo que la base es la
# misma, sin importar por donde se escriba."
curl -i http://localhost:5000/books
```

```bash
# (dentro de la VM) Limpieza: borro el libro de prueba por titulo, no por id.
# DECIR: "Borro por título para no depender del id que haya asignado MySQL."
sudo mysql -u root -proot myflaskapp -e 'DELETE FROM books WHERE title="Desde SQL";'
```

---

## 4. Prueba de persistencia

Detener la Parte 3 con `Ctrl+C` antes de apagar la VM.

```bash
# (host) Apaga la VM sin destruirla.
# DECIR: "Apago la maquina virtual. Esto no borra nada."
vagrant halt
```

```bash
# (host) Comprueba el estado: poweroff.
# DECIR: "Quedo en poweroff, que significa apagada pero conservando el disco."
vagrant status
```

```bash
# (host) Vuelve a encender. NO debe volver a aprovisionar.
# DECIR: "La vuelvo a levantar. Noten que no vuelve a instalar nada."
vagrant up
```

```bash
# (dentro de la VM) MySQL levanta solo, porque el paso 02 lo dejo habilitado al arranque.
# DECIR: "MySQL ya está activo sin que yo lo haya iniciado, porque el aprovisionamiento
# lo habilito con systemctl enable."
systemctl is-active mysql
```

```bash
# (dentro de la VM) Los datos siguen aqui.
# DECIR: "Los datos siguen en la tabla. Eso es persistencia."
sudo mysql -u root -proot myflaskapp -e "SELECT * FROM books;"
```

La respuesta corta, memorizada:

> "Los datos sobreviven porque MySQL escribe en el disco de la máquina virtual, no en la memoria del proceso. Apagar y encender no borra el disco, y el aprovisionamiento solo corre en el primer `vagrant up`. Lo único que borra el disco es `vagrant destroy`."

Lo que **no** hay que hacer durante la defensa:

| Comando | Que hace | Usar |
|---|---|---|
| `vagrant halt` + `vagrant up` | Conserva los datos | Sí |
| `vagrant destroy` | Borra el disco, hay que reprovisionar | No, salvo que te lo pidan |
| `vagrant provision` | **Resetea la base** | No durante la defensa |

> Que digo si te preguntan por `vagrant provision`: "Cuidado, `vagrant provision` vuelve a correr el paso 02, y `init.sql` hace `DROP TABLE IF EXISTS books`. Es un reset total de los datos. Por eso en la demostración de persistencia uso `halt` y `up`, que no reprovisionan."

---

## 5. El Desafio en Node

El Desafio sí puede correr al mismo tiempo que la Parte 1 o la Parte 3, porque escucha en el puerto 3000.

```bash
# (dentro de la VM) Detener el Flask que este corriendo con Ctrl+C, para no mezclar los logs.
```

```bash
# (dentro de la VM) Entra a la carpeta del Desafio.
# DECIR: "Esta es la misma API, en JavaScript. No cambie el contrato: cambie el lenguaje."
cd /home/vagrant/app/desafio-node
```

```bash
# (dentro de la VM) Arranca el servidor de Express en el puerto 3000.
# OJO: package.json no define un script "start", se ejecuta el archivo directo.
# DECIR: "Levanto Express. Escucha en el 3000 y en 0.0.0.0, así que además de la VM
# lo alcanzo desde Windows."
node server.js
```

### 5.1 Las mismas cinco consultas

```bash
# (dentro de la VM) Listado. Misma respuesta que Flask.
# DECIR: "El listado es identico."
curl -i http://localhost:3000/books
```

```bash
# (dentro de la VM) Un libro por id.
curl -i http://localhost:3000/books/2
```

```bash
# (dentro de la VM) Crea un libro. Esta vez la respuesta SI trae el id.
# DECIR: "Aqui si recibo el id, porque mysql2 me lo da en result.insertId. Esa es la
# mejora frente a la Parte 3."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Rayuela","description":"Novela","author":"Cortazar"}' http://localhost:3000/books
```

```bash
# (dentro de la VM) Actualiza el autor. Esta vez devuelve el libro YA actualizado.
# DECIR: "Y el PUT devuelve el estado final del libro, no el anterior."
curl -i -X PUT -H "Content-Type: application/json" -d '{"author":"Jorgito"}' http://localhost:3000/books/2
```

```bash
# (dentro de la VM) El id 99 no existe y aqui si responde 404 con un cuerpo JSON.
# DECIR: "Aqui si hay 404, con un mensaje en el cuerpo. Es la tercera mejora."
curl -i http://localhost:3000/books/99
```

### 5.2 Prueba entre los dos lenguajes

Deja las dos APIs vivas al mismo tiempo, cada una en su terminal: la Parte 3 con `python3 apirest_mysql.py` en el puerto 5000, y el Desafio con `node server.js` en el puerto 3000. Esto es posible porque usan puertos distintos.

```bash
# (dentro de la VM) Creo un libro por la API de Node, en el puerto 3000.
# DECIR: "Creo un libro por Node, y noten que la respuesta trae el id."
curl -i -X POST -H "Content-Type: application/json" -d '{"title":"Desde Node","description":"Insertado a mano","author":"Juan"}' http://localhost:3000/books
```

```bash
# (dentro de la VM) Ahora lo leo por Flask, en el puerto 5000. Aparece sin haber pasado por Node.
# DECIR: "Lo leo con Flask y el libro que creó Node aparece igual, sin ninguna traducción.
# Las dos APIs apuntan a la misma tabla myflaskapp, y el lenguaje no es lo que define el dato."
curl -i http://localhost:5000/books
```

La misma prueba, escribiendo directo en SQL, para demostrar que el dato no depende de ninguna de las dos APIs:

```bash
# (dentro de la VM) Inserto un libro con la consola de MySQL, sin pasar por ninguna API.
# DECIR: "Tambien puedo escribir directo en la base, y las dos APIs lo ven."
sudo mysql -u root -proot myflaskapp -e 'INSERT INTO books VALUES(NULL,"Desde SQL","Insertado a mano","Juan");'
```

```bash
# (dentro de la VM) Limpieza: borro los libros de la demostracion.
# DECIR: "Limpio los datos de prueba para no alterar la base."
sudo mysql -u root -proot myflaskapp -e 'DELETE FROM books WHERE title IN ("Desde Node","Desde SQL");'
```

> Que digo para cerrar: "El entregable real de la práctica no es el código en Flask ni el código en Node: es el contrato. Son dos lenguajes, dos frameworks y dos drivers distintos, y aun así las dos APIs se comportan igual. Si yo regalo el código, el contrato me sirve. Si regalo el contrato, cualquier equipo lo puede implementar en el lenguaje que quiera."

---

## 6. Si algo se rompe

Indice rapido. El detalle está en [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

| Sintoma | Causa probable | Que hacer |
|---|---|---|
| `AttributeError: 'NoneType' object has no attribute 'cursor'` | Flask-MySQLdb sin fijar; instalo PyMySQL en vez de mysqlclient | Verificar el pin en `provision/03-python.sh` |
| `Address already in use` en el puerto 5000 | Parte 1 y Parte 3 corriendo a la vez | `Ctrl+C` en la otra terminal |
| `Can't connect to MySQL server` | MySQL detenido | `sudo systemctl start mysql` |
| `Access denied for user 'root'@'localhost'` | Contraseña distinta de `root` | Usar `-u root -proot` |
| `There are errors in the configuration of this machine` | Opción `owner:` obsoleta de un Vagrantfile viejo | Actualizar el `Vagrantfile` del repositorio |
| pip falla al compilar `mysqlclient` | Faltan las dependencias de compilación | Reejecutar `vagrant provision` tras confirmar el paso 01 |
| `npm ci` falla | `package-lock.json` desalineado de `package.json` | Reejecutar `provision/04-node.sh` |
| `Falta la variable de entorno UBIDOTS_TOKEN` | No exportaste el token en esa terminal | `export UBIDOTS_TOKEN=BBUS-...` |
| Ubidots responde 401 | Token equivocado, vencido o de otro dispositivo | Revisar token y etiqueta del dispositivo |
| Ubidots se queda sin datos | Cuota de 4000 puntos por día consumida | Esperar el reinicio del cupo |
| `curl: (7) Failed to connect ... Connection refused` | El servidor no está corriendo | Verificar en que terminal quedo |

---

## 7. Las cinco preguntas más probables

**1. Cual es la diferencia entre la Parte 1 y la Parte 3?**
La Parte 1 guarda los libros en una lista de Python dentro del proceso, y el proceso no escribe en ningún disco: si lo detengo, los datos desaparecen. La Parte 3 ejecuta exactamente el mismo SQL contra MySQL, y los datos quedan en la tabla `books` del disco de la VM, así que sobreviven al reinicio.

**2. Por qué el `id` en la Parte 1 lo genera el código y en la Parte 3 lo genera MySQL?**
La Parte 1 no tiene base de datos, así que el id tiene que salir de algún lado: el código toma el último de la lista y le suma uno, `books[-1]['id'] + 1`. En la Parte 3 la columna está declarada `AUTO_INCREMENT`, así que MySQL lleva la cuenta y garantiza unicidad. Esa diferencia es la causa directa de que el `POST` de la Parte 3 no pueda devolver el id: el código ejecuta el `INSERT` y nunca vuelve a leer el valor generado.

**3. Por qué la Parte 3 devuelve 500 en vez de 404?**
Porque `get_book()` ejecuta `cur.fetchall()` y después accede a `book[0]` sin comprobar que la lista tenga elementos. Con un id inexistente la consulta devuelve cero filas, `book[0]` lanza `IndexError`, y Flask responde con su página genérica de 500. No es un descuido del ejercicio: es la línea base que el Desafio viene a corregir, porque la versión en Node sí valida `rows.length === 0` y responde 404.

**4. Por qué los datos sobreviven a `vagrant halt` y `vagrant up`?**
Porque los datos están en el disco de la máquina virtual, no en la memoria de un proceso. `halt` apaga la VM sin borrar el disco, y el aprovisionamiento solo corre en el primer `vagrant up`, así que al volver a levantar la máquina los datos siguen ahí. Lo único que borra el disco es `vagrant destroy`.

**5. Por qué hacer la misma API en dos lenguajes?**
Para demostrar que el contrato REST es el entregable, no el framework. Flask con `Flask-MySQLdb` y Express con `mysql2` son tecnologías distintas, y aun así las dos exponen el mismo contrato. Además, la versión en Node mejora tres cosas concretas de la línea base de Flask: responde 404 en vez de 500, el `PUT` devuelve el estado final del recurso, y el `POST` devuelve el id generado.
