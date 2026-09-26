# Práctica IoT API REST: donde viven los datos

Cuatro etapas de la misma API REST de libros, cambiando **solamente donde se guardan los datos**: lista en memoria, nube de Ubidots, MySQL y Node.js. El hilo pedagogico de la práctica es la persistencia, no la calidad del código.

| Etapa | Directorio | Tecnología | Puerto | Donde viven los datos |
|---|---|---|---|---|
| Parte 1 | `app/parte1-memoria/` | Flask 2.3.3 | 5000 | Lista de Python en RAM, se pierde al apagar el proceso |
| Parte 2 | `app/parte2-ubidots/` | Python + `requests` | ninguno | Nube de Ubidots, 4000 puntos de datos por día |
| Parte 3 | `app/parte3-mysql/` | Flask 2.3.3 + MySQL 8.0.46 | 5000 | Tabla `books` en `myflaskapp`, sobre el disco de la VM |
| Desafio | `app/desafio-node/` | Node 22 + Express 5.2.1 | 3000 | La misma tabla `books`, leida desde otro lenguaje |

Las cuatro etapas comparten un único contrato REST (`GET/POST/PUT/DELETE` sobre `/books`). Lo que cambia entre una y otra es la respuesta a una sola pregunta: **que pasa con el dato cuando el proceso termina**.

## Arquitectura

```
  HOST  (Windows / macOS / Linux)
  +------------------------------------------------------+
  |  Repo  practica-iot-api-rest/                        |
  |    Vagrantfile   provision/   app/   docs/           |
  |    .env.example  .gitignore                          |
  +--------------------------+---------------------------+
                             |  vagrant up --provision
                             |  (VirtualBox, sin /vagrant sincronizado)
                             v
  VM  bento/ubuntu-22.04   hostname: servidorRest
  +------------------------------------------------------+
  |  IP privada 192.168.60.3                             |
  |  Codigo en /home/vagrant/app  (copiado al aprovisionar)|
  |                                                      |
  |   parte1-memoria    Flask  :5000                     |
  |   parte2-ubidots    Python --> industrial.api.ubidots.com
  |   parte3-mysql      Flask  :5000                     |
  |   desafio-node      Node   :3000 (0.0.0.0)           |
  |            |                                         |
  |            v                                         |
  |   MySQL 8.0.46   root/root   :3306                   |
  |   bind-address 0.0.0.0                               |
  |   base myflaskapp   tabla books                      |
  |   DATOS EN EL DISCO DE LA VM  <-- aqui sobreviven    |
  +------------------------------------------------------+
                             |
                             |  :3306 en 0.0.0.0 (solo root@localhost)
                             v
  Herramientas en Windows (por ejemplo MySQL Workbench)
```

La carpeta compartida `/vagrant` está **deshabilitada** a propósito. El provisioner `file` copia `app/` adentro de la VM, así el resultado es identico a un `vagrant destroy` seguido de un `vagrant up` limpio y nadie edita por error `/vagrant` en vez de `/home/vagrant`.

## Requisitos

| Requisito | Detalle |
|---|---|
| Sistema operativo | Windows, macOS o Linux con Hypervisor |
| VirtualBox | Necesario: el `Vagrantfile` no declara proveedor |
| Vagrant | Versión 2.x o superior (3.x funciona) |
| Disco | Al menos 4 GB libres para la box de Ubuntu 22.04 |
| Red | La primera vez descarga `bento/ubuntu-22.04`; después funciona sin internet, salvo Ubidots |

Todos los comandos `vagrant` se ejecutan **desde la raiz del repositorio**, en el host, en la carpeta que contiene el `Vagrantfile`.

## Inicio rapido (5 minutos)

```bash
# (host) Clona el repositorio y entra a la carpeta raiz.
git clone <url-del-repositorio> practica-iot-api-rest
cd practica-iot-api-rest

# (host) Crea la VM y ejecuta los 4 scripts de aprovisionamiento.
# La primera vez descarga la box y compila mysqlclient: puede tardar 10-15 minutos.
vagrant up --provision

# (host) Entra a la VM. Ahi vive el codigo, en /home/vagrant/app
vagrant ssh servidorRest
```

Verificación rapida desde la VM:

```bash
# (dentro de la VM) Comprueba que MySQL responde.
systemctl is-active mysql

# (dentro de la VM) Comprueba que la tabla tiene los 2 libros semilla.
sudo mysql -u root -proot myflaskapp -e "SELECT COUNT(*) AS libros FROM books;"
```

Si ambos responden, el laboratorio está listo. Para apagarlo sin perder datos: `vagrant halt` (host).

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `Vagrantfile` | Define la VM `servidorRest`, desactiva `/vagrant` y ordena los provisioners |
| `provision/01-system-deps.sh` | `build-essential`, `python3-dev`, `default-libmysqlclient-dev`, `curl`, `mysql-client` |
| `provision/02-mysql.sh` | Instala MySQL 8, fija `root`/`root`, habilita `bind-address 0.0.0.0`, importa `init.sql` |
| `provision/03-python.sh` | Instala Flask 2.3.3, Flask-MySQLdb 1.0.1, mysqlclient, requests |
| `provision/04-node.sh` | Instala Node 22 desde NodeSource y corre `npm ci` en `app/desafio-node/` |
| `app/parte1-memoria/apirest.py` | API Flask con la lista de libros en memoria |
| `app/parte1-memoria/README-origen.md` | Instrucciones de arranque que trae el proyecto de origen |
| `app/parte2-ubidots/testUbidots.py` | Cliente que envía 5 variables a un dispositivo de Ubidots cada 10 s |
| `app/parte3-mysql/apirest_mysql.py` | La misma API Flask, pero leida y escrita en MySQL |
| `app/parte3-mysql/init.sql` | Crea `myflaskapp`, la tabla `books` con `AUTO_INCREMENT` y 2 filas semilla |
| `app/desafio-node/server.js` | La misma API en Express, con las correcciones del Desafio |
| `app/desafio-node/package.json` | Declara `express ^5.2.1` y `mysql2 ^3.24.4` |
| `app/desafio-node/package-lock.json` | Versiones exactas que reproduce `npm ci` |
| `.env.example` | Plantilla con `UBIDOTS_TOKEN` y `UBIDOTS_DEVICE_LABEL` |
| `.gitignore` | Excluye `.env`, `.vagrant/`, `node_modules/` y archivos de MySQL |
| `docs/` | Esta documentación |

## Contrato REST común

Las tres etapas que exponen `/books` responden igual en exito. Las diferencias están en la gestion de errores, y son el material de discusión de la práctica.

| Caso | Parte 1 (memoria) | Parte 3 (MySQL) | Desafio (Node) |
|---|---|---|---|
| `GET /books` | 200 | 200 | 200 |
| `GET /books/2` | 200 | 200 | 200 |
| `GET /books/99` (inexistente) | 404 | 500 | 404 `{"error":"Not found"}` |
| `POST /books` | 201, incluye `id` | 201, **devuelve el cuerpo enviado, sin `id`** | 201, incluye `id` |
| `POST /books` sin `title` | 400 | 400 | 400 |
| `PUT /books/2` | 200, devuelve el libro **actualizado** | 200, devuelve el libro **anterior** al cambio | 200, devuelve el libro **actualizado** |
| `PUT /books/99` (inexistente) | 404 | 500 | 404 `{"error":"Not found"}` |
| `DELETE /books/<id>` | 200 `{"result": true}` | 200 `{"result": true}` | 200 `{"result": true}` |
| `GET` sobre un id borrado | 404 | 500 | 404 `{"error":"Not found"}` |

Las tres diferencias de la columna de MySQL son **una línea base deliberada**, no un descuido. En `app/parte3-mysql/apirest_mysql.py`, `get_book()` hace `cur.fetchall()` y luego `book[0]` sin verificar que la lista tenga elementos, así que un id inexistente lanza `IndexError` y Flask responde 500. La Parte 1 sí valida con `if len(book) == 0: abort(404)` y la versión en Node responde 404. El Desafio consiste justamente en corregir eso.

Parte 2 no expone `/books`: no es un servidor, es un cliente que publica sensores en Ubidots.

## Los puertos

| Servicio | Puerto | Bind | Puede correr junto a |
|---|---|---|---|
| Parte 1 (Flask) | 5000 | 127.0.0.1 | Desafio (Node) |
| Parte 3 (Flask) | 5000 | 127.0.0.1 | Desafio (Node) |
| Desafio (Node) | 3000 | 0.0.0.0 | Parte 1 o Parte 3 |

Las partes 1 y 3 usan el mismo puerto y **no pueden correr al mismo tiempo**. El Desafio en Node sí puede.

> **Regla importante: todos los `curl` de estas guías se escriben dentro de la VM**, en la Terminal 2 que abres con `vagrant ssh servidorRest`. Cada guía usa la dirección `localhost`, y ese `localhost` es el de la VM, no el de Windows. El `Vagrantfile` **no declara ningún `forwarded_port`**, así que el `localhost` de Windows no tiene a qué reenviar el puerto 5000: un `curl` a `http://localhost:5000/...` lanzado desde Windows falla siempre con *connection refused*, aunque el servidor esté corriendo y los logs muestren la petición. Arrancar con `--host=0.0.0.0` no cambia esto: esa opción solo controla la dirección de escucha **dentro** de la VM, no crea un reenvío de puertos. Lo único que hace falta para demostrar es quedarse en la Terminal 2. Ver [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), sección 13.

## Documentación

| Documento | Para qué sirve |
|---|---|
| [docs/CHULETA-SUSTENTACION.md](docs/CHULETA-SUSTENTACION.md) | Chuleta maestra de la defensa oral, ordenada y lista para copiar y pegar |
| [docs/PARTE-1-MEMORIA.md](docs/PARTE-1-MEMORIA.md) | Parte 1 a fondo: la volatilidad de la memoria RAM |
| [docs/PARTE-2-UBIDOTS.md](docs/PARTE-2-UBIDOTS.md) | Parte 2 a fondo: token, cuota diaria, las 5 variables y las dos formas de autenticación |
| [docs/PARTE-3-MYSQL.md](docs/PARTE-3-MYSQL.md) | Parte 3 a fondo: `AUTO_INCREMENT`, las 3 rarezas deliberadas y la persistencia |
| [docs/DESAFIO-NODE.md](docs/DESAFIO-NODE.md) | El Desafio: la misma API en otro lenguaje, con 3 mejoras |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Sintoma, causa y corrección de cada error conocido |

Si la defensa oral es lo único que te importa, empieza por la chuleta. Si estas instalando el laboratorio por primera vez, empieza aquí y sigue el orden de las partes.

## Versiones fijadas: no las cambies

`provision/03-python.sh` fija las versiones de Python de forma deliberada. Actualizarlas rompe el laboratorio:

| Versión fijada | Por que |
|---|---|
| `Flask-MySQLdb==1.0.1` | Esta versión usa **mysqlclient**, una extensión en C. Las versiones más recientes migran a PyMySQL (Python puro), que no negocia correctamente `caching_sha2_password` de MySQL 8. Sin el pin, `mysql.connection` queda en `None` y **todos los endpoints devuelven 500** con `AttributeError: 'NoneType' object has no attribute 'cursor'`. |
| `Flask==2.3.3` | Flask 2.3 en adelante exige versiones compatibles de Jinja y werkzeug; sin el pin la app falla al importar. |
| `mysqlclient 2.1.1` (transitiva) | Se compila desde el código fuente, por eso `provision/01-system-deps.sh` instala `build-essential`, `pkg-config`, `python3-dev` y `default-libmysqlclient-dev`. Si el paso 01 falla, el paso 03 falla. |

Consecuencia práctica: **no actualices estas versiones y no cambies el driver a PyMySQL**. Si ves el error de `NoneType`, el diagnóstico está en [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

El paso 04 también está fijado por una razon equivalente: Ubuntu 22.04 trae Node 12 y Express 5 exige Node 18 o superior, así que `provision/04-node.sh` instala Node 22 desde NodeSource. Y usa `npm ci`, no `npm install`, para reproducir exactamente `package-lock.json`.

## Seguridad

| Tema | Que hacer |
|---|---|
| Token de Ubidots | Es una credencial personal e intransferible. Va en la variable de entorno `UBIDOTS_TOKEN`; el archivo `.env` está en `.gitignore` y **nunca** se sube. Al repositorio solo va `.env.example`, sin el valor real. Cada estudiante usa su propio token: no se comparte, no se copia el de un companero. |
| Token en la URL | Ubidots acepta el token como `?token=`. Funciona, pero queda en el historial del shell y en los logs del servidor. Se muestra en la práctica solo para comparar; la forma correcta es la cabecera `X-Auth-Token`. |
| `bind-address = 0.0.0.0` en MySQL | Lo establece `provision/02-mysql.sh` para permitir herramientas gráficas desde Windows. **No abre root a la red**: el único usuario existente es `root@localhost`, así que un cliente remoto que intente entrar como root se rechaza igual. Aun así, MySQL queda escuchando en toda la red privada de Vagrant, no solo en loopback. |
| Puerto 5000 | Flask arranca con `app.run(debug=True)`, que escucha solo en `127.0.0.1` dentro de la VM. Para exponerlo a Windows hay que arrancar con `python3 -m flask run --host=0.0.0.0`. |
| Puerto 3000 | `app/desafio-node/server.js` escucha en `0.0.0.0:3000` a propósito, para que el companero lo alcance desde el host. |
| Contrasena de MySQL | `root` / `root` es una credencial de laboratorio local. No la reutilices en ningun otro servicio. |

## Procedencia

Este repositorio es una práctica de estudiante de Compunube. Existe para que los companeros puedan reproducir exactamente el mismo escenario y defender las mismas conclusiones.

| Parte | Origen |
|---|---|
| Parte 1 | `app/parte1-memoria/apirest.py` deriva de <https://github.com/omondragon/APIRestFlask>, el punto de partida entregado para la práctica. Las instrucciones de arranque de ese proyecto están en `app/parte1-memoria/README-origen.md`. |
| Parte 2 | `app/parte2-ubidots/testUbidots.py` deriva de <https://github.com/omondragon/UbidotsClient> y de la documentación oficial de Ubidots STEM. |
| Parte 3 | `app/parte3-mysql/apirest_mysql.py` es el mismo contrato REST de la Parte 1, con la capa de MySQL encima. |
| Desafio | `app/desafio-node/server.js` es el mismo contrato REST de nuevo, en JavaScript. |
