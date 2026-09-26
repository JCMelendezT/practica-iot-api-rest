# Solución de problemas

Sintoma, causa y solución para cada error conocido del laboratorio. Ordenado por frecuencia, del error más probable al más raro.

## Regla de oro

| Comando | Efecto |
|---|---|
| `vagrant halt` + `vagrant up` | Apaga y enciende la VM **conservando los datos** |
| `vagrant provision` (o `vagrant up --provision`) | Vuelve a correr los 4 scripts y **resetea la base**: `init.sql` ejecuta `DROP TABLE IF EXISTS books` y siembra las 2 filas originales |
| `vagrant destroy` | Borra el disco de la VM y hay que reprovisionar desde cero |

Si un arreglo te pide reprovisionar y tu base tiene datos que te importan, sacalos primero:

```bash
# (dentro de la VM) Exporta los datos de la tabla antes de reprovisionar.
mysqldump -u root -proot myflaskapp books > /home/vagrant/books-backup.sql
```

## Indice de síntomas

| Sintoma | Sección |
|---|---|
| `AttributeError: 'NoneType' object has no attribute 'cursor'` | 1 |
| `Address already in use` o el puerto 5000 ocupado | 2 |
| `Can't connect to MySQL server` | 3 |
| `Access denied for user 'root'@'localhost'` | 4 |
| `There are errors in the configuration of this machine` | 5 |
| `vagrant up` se queda descargando la box | 6 |
| pip falla al compilar `mysqlclient` | 7 |
| `npm ci` falla | 8 |
| `Falta la variable de entorno UBIDOTS_TOKEN` | 9 |
| Ubidots responde 401 | 10 |
| Ubidots no acepta más datos (cuota agotada) | 11 |
| `curl: (7) Failed to connect ... Connection refused` | 12 |
| El `curl` a `localhost` funciona en la VM y falla en Windows | 13 |

La regla de oro está arriba: **no confundas `vagrant provision` con `vagrant halt` + `vagrant up`**. El primero resetea la base, el segundo la conserva.

---

## 1. `AttributeError: 'NoneType' object has no attribute 'cursor'`

Cada endpoint de la Parte 3 devuelve 500 con este error.

**Causa.** `mysql.connection` está en `None`. Esto pasa cuando `Flask-MySQLdb` se instalo en una versión más nueva que la del pin. Desde 1.0.1 en adelante el paquete dejo de usar `mysqlclient` (extensión en C) y paso a `PyMySQL` (Python puro), que **no negocia correctamente** el plugin `caching_sha2_password` de MySQL 8. El resultado es que `Flask-MySQLdb` no puede establecer el objeto de conexión y lo deja en `None`.

**Solución.** Verifica las versiones instaladas dentro de la VM:

```bash
# (dentro de la VM) Comprueba que las versiones vienen del pin.
pip3 list | grep -iE "flask-mysqldb|mysqlclient|pymysql"
```

Deben verse `Flask-MySQLdb 1.0.1` y `mysqlclient` (y no `PyMySQL`). Si aparece `PyMySQL`, el pin se perdio.

**Corrección.** El pin vive en `provision/03-python.sh`; el arreglo operativo es reprovisionar el paso 03:

```bash
# (host) Vuelve a correr el paso de Python. Reinstala las versiones fijadas.
vagrant provision
```

No lo digas en la defensa sin motivo: `vagrant provision` resetea la base (ver regla de oro). Si prefieres no tocar los datos, pip dentro de la VM:

```bash
# (dentro de la VM) Reinstala la version fijada, sin tocar la base de datos.
sudo pip3 install --force-reinstall "Flask-MySQLdb==1.0.1"
```

**Prevención.** No actualices los pines de `provision/03-python.sh`. Están fijados a propósito y el motivo está explicado en el propio archivo.

---

## 2. `Address already in use` al arrancar una Parte 1 o Parte 3

**Causa.** Las partes 1 y 3 escuchan en el **mismo puerto 5000**. No pueden correr a la vez; el segundo Flask falla en el arranque.

**Solución.** Detener el que este corriendo. En la terminal donde corre, `Ctrl+C`. Con `debug=True`, Flask levanta un proceso de recarga, así que puede hacer falta detenerlo dos veces.

**Dato útil.** El Desafio en Node escucha en el 3000, así que si corre junto a cualquiera de los dos, no hay conflicto.

---

## 3. `Can't connect to MySQL server`

**Causa.** MySQL no está corriendo dentro de la VM.

**Solución.**

```bash
# (dentro de la VM) Comprueba el estado del servicio.
systemctl is-active mysql
```

```bash
# (dentro de la VM) Levanta MySQL y dejalo habilitado para el arranque.
sudo systemctl start mysql
sudo systemctl enable mysql
```

Si el servicio dice `active`, el problema es otro: revisa la contrasena (sección 4) o el puerto 3306. El usuario root solo existe como `root@localhost`, así que desde fuera de la VM un login como root se rechaza siempre: eso es normal, no es un fallo.

---

## 4. `Access denied for user 'root'@'localhost'`

**Causa.** La autenticación no matchea. El laboratorio deja a root con contrasena `root` y plugin `caching_sha2_password`. Si la petición no tiene contrasena, o usa otra, MySQL rechaza.

**Solución.** Usar la forma completa:

```bash
# (dentro de la VM) Con contrasena explicita.
sudo mysql -u root -proot myflaskapp -e "SELECT 1;"
```

Alternativa dentro de la VM, si el servidor sigue con `auth_socket` (login por usuario del sistema):

```bash
# (dentro de la VM) Entra sin contrasena y normaliza root a la forma del laboratorio.
sudo mysql --protocol=socket -u root
```

```sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'root';
FLUSH PRIVILEGES;
exit;
```

Ese es exactamente el estado que deja `provision/02-mysql.sh`.

---

## 5. `There are errors in the configuration of this machine`

**Causa.** El `Vagrantfile` declara la opción `owner:` en el provisioner `file`. Esa opción **dejo de existir en Vagrant 3** y `vagrant up` aborta antes de crear la VM.

**Solución.** No es un problema de tu máquina: es un Vagrantfile viejo. Usa la versión del repositorio, que no declara `owner:` porque la carpeta compartida está deshabilitada y el `file` provisioner copia con el usuario `vagrant` por defecto.

Si tienes modificaciones locales del `Vagrantfile`, quita la línea `owner:` y repite:

```bash
# (host) Vuelve a validar la configuracion de la VM.
vagrant validate
```

```bash
# (host) Y vuelve a levantarla.
vagrant up
```

---

## 6. `vagrant up` se queda descargando la box

**Causa.** La box `bento/ubuntu-22.04` pesa varios cientos de megabytes y se descarga una sola vez. La primera ejecución tarda entre 5 y 15 minutos según la conexión.

**Solución.** Deja que termine. Si falla a mitad, reintenta; la descarga se reanuda desde donde quedo. Verifica la progresión con `vagrant box list` una vez terminada:

```bash
# (host) Muestra las boxes descargadas.
vagrant box list
```

Después de la primera descarga, `vagrant up` no vuelve a bajar nada y arranca sin internet (salvo la Parte 2, que sí lo necesita para Ubidots).

---

## 7. pip falla al compilar `mysqlclient`

**Causa.** `mysqlclient` se compila desde el código fuente. Para eso hacen falta `build-essential`, `pkg-config`, `python3-dev` y `default-libmysqlclient-dev`, que instala `provision/01-system-deps.sh`. Si el paso 01 fallo o se salto, el paso 03 falla al compilar.

**Solución.** Vuelve a correr el aprovisionamiento, que ejecuta los pasos en el orden del `Vagrantfile`:

```bash
# (host) Reprovisiona completa, pasos 01 a 04, en orden.
vagrant provision
```

**Prevención.** El orden de los `provisioner` en el `Vagrantfile` es obligatorio: 01 antes de 03. No los reordenes.

---

## 8. `npm ci` falla

**Causa.** `npm ci` instala exactamente lo que dice `package-lock.json`; rechaza si `package.json` y `package-lock.json` no están sincronizados. También falla sin `node_modules` disponibles si el paso 04 se ejecuto antes de haber copiado `app/`.

**Solución.** Reprovisionar el paso 04:

```bash
# (host) Vuelve a correr la instalacion de Node.
vagrant provision
```

Dentro de la VM, sin tocar la base de datos:

```bash
# (dentro de la VM) Reinstala desde el lock, en la carpeta del Desafio.
cd /home/vagrant/app/desafio-node
npm ci --no-audit --no-fund
```

Si el enunciado es un error de versión de Node (por ejemplo `spawn node ENOENT` o "engines"), comprueba la versión:

```bash
# (dentro de la VM) Express 5 exige Node 18 o superior.
node -v
```

Ubuntu 22.04 trae Node 12, insuficiente. El paso 04 instala Node 22 desde NodeSource; si ves una versión menor a 18, el paso 04 no completo.

---

## 9. `[ERROR] Falta la variable de entorno UBIDOTS_TOKEN`

**Causa.** `testUbidots.py` se ejecuto sin la variable de entorno. Muestra, en `stderr`, el mensaje de ayuda y termina con código de salida 1. Es un fallo deliberado y rapido: prefiere avisarte antes de repetir cinco veces un 401 y hacerte creer que el internet está roto.

```bash
# (dentro de la VM) Exporta tu token personal en ESTA terminal.
export UBIDOTS_TOKEN=BBUS-pega-aqui-tu-token
```

La variable es por terminal: si abres otra `vagrant ssh`, hay que exportarla de nuevo.

**Solución si falta el token.** Crear la cuenta de Ubidots y el token: ver [PARTE-2-UBIDOTS.md](PARTE-2-UBIDOTS.md). El token empieza con `BBUS-` y se saca de la consola de Ubidots: Dispositivos, pestana Ajustes, Token de API.

---

## 10. Ubidots responde 401 (no autorizado)

**Causa.** El token no es valido para la petición. Causas concretas:

| Causa | Detección |
|---|---|
| Token mal copiado | Revisar que no haya espacios ni caracteres extra en el `export` |
| Token de otra cuenta | Ubidots asocia el token a un dispositivo de tu cuenta |
| Token vencido o revocado | Revisar en la consola la validez del token |
| Etiqueta del dispositivo distinta de `machine` | El código publica en `/devices/machine`; si el dispositivo se llama de otro modo, falla |

Comprobación rapida:

```bash
# (dentro de la VM) Mira cuantos caracteres tiene la variable: el token es largo.
echo ${#UBIDOTS_TOKEN}
```

La forma definitiva de probar el token es hacer la petición `POST` de [PARTE-2-UBIDOTS.md](PARTE-2-UBIDOTS.md): si responde 200 y actualiza el dispositivo, el token es valido.

**Dato útil.** El device label debe coincidir con el dispositivo real: si tu dispositivo en Ubidots tiene otro label, editalo en la consola o crea uno llamado `machine`.

---

## 11. Ubidots no acepta más datos (cuota agotada)

**Causa.** El plan STEM tiene **4000 puntos de datos por día**. El script envía 5 variables cada 10 segundos, unos 1800 puntos por hora: un día de ejecución continua agota el cupo.

**Solución.** No hay tope manual que puedas apagar: la cuota se reinicia por periodo. Si el dashboard deja de actualizarse o la API devuelve errores de capacidad, la cuota de datos de ese día se consumio.

**Prevención.** Correr el script solo para demostrar, uno o dos minutos, y cortar con `Ctrl+C`. No dejar el laboratorio encendido con el script corriendo.

---

## 12. `curl: (7) Failed to connect ... Connection refused`

**Causa.** Nada está escuchando en ese puerto en el momento del `curl`.

| Puertos | Estado si falla |
|---|---|
| 5000 (Parte 1 o 3) | El Flask no arranco, o se detuvo con `Ctrl+C` |
| 3000 (Desafio) | `node server.js` no está corriendo |

Un segundo caso, tipico en la defensa: el `curl` se ejecuta desde **dentro de la VM**, y el servidor se quedo en otra sesión de SSH que se cerro. Cada `vagrant ssh` es una máquina con sus propios procesos: si la terminal del servidor se cerro, el proceso murio con ella.

Verificación de puertos:

```bash
# (dentro de la VM) Ve que servicios escuchan y en que puerto.
sudo ss -tlnp | grep -E "5000|3000" || echo "nada escuchando en 5000 o 3000"
```

```bash
# (dentro de la VM) Si la Parte 1 o 3 cayo, la levanta de nuevo.
cd /home/vagrant/app/parte1-memoria && python3 apirest.py
```

```bash
# (dentro de la VM) Si el Desafio cayo, la levanta de nuevo.
cd /home/vagrant/app/desafio-node && node server.js
```

**Causa adicional especifica de Flask.** `app.run(debug=True)` escucha solo en `127.0.0.1`; si ejecutas el `curl` desde **Windows** apuntando a la IP de la VM, el puerto 5000 no responde aunque el servidor corra. No es un error: es el bind. Las soluciones están en [PARTE-1-MEMORIA.md](PARTE-1-MEMORIA.md): arrancar con `python3 -m flask run --host=0.0.0.0`, o hacer el `curl` desde dentro de la VM. El Desafio en Node escucha en `0.0.0.0`, así que desde Windows sí responde el 3000.

---

## 13. El `curl` a `localhost` funciona en la VM y falla en Windows

**Sintoma.** En la Terminal 2 (dentro de la VM) el `curl` a `http://localhost:5000/books` responde bien. Entras a una terminal de Windows, ejecutas el mismo `curl` y sale `curl: (7) Failed to connect to localhost port 5000: Connection refused`, o en PowerShell `Invoke-WebRequest : No se puede establecer una conexión`. El servidor sigue corriendo y la Terminal 2 sigue respondiendo: es el mismo proceso.

**Causa.** Son dos máquinas distintas y cada una tiene su propio `localhost`. El `Vagrantfile` no declara ningún `forwarded_port`, así que el puerto 5000 de la VM existe únicamente dentro de la red privada de Vagrant, y el `localhost` de Windows no tiene nada a qué reenviarlo. Es el comportamiento esperado, no un fallo de la máquina virtual. Además, la parte 1 y la parte 3 escuchan en `127.0.0.1` (ver sección 12), así que ni siquiera alcanzan la IP privada de la VM desde Windows.

**Arreglo.** Escribir el `curl` en la Terminal 2, que es donde viven los `curl` de estas guías. Si de verdad necesitas disparar el `curl` desde Windows, no es la vía de la demo: usa la Terminal 2.

**Lo que NO es el arreglo.** Agregar `--host=0.0.0.0` no arregla este caso: esa opción solo cambia la dirección de escucha **dentro** de la VM, no crea un reenvío de puertos en el host. Con `--host=0.0.0.0` el puerto 5000 se vuelve alcanzable en la IP privada de la VM (`192.168.60.3`), y el `localhost` de Windows sigue sin funcionar.

---

## Checklist rapido antes de la defensa

- [ ] `vagrant up` deja `systemctl is-active mysql` en `active`
- [ ] Las partes 1 y 3 responden en el 5000 desde dentro de la VM
- [ ] El Desafio responde en el 3000, también desde Windows si hace falta
- [ ] `UBIDOTS_TOKEN` exportado y probado con el `curl` de la sección 10
- [ ] Corriste el script de sensores un minuto, lo cortaste con `Ctrl+C` y el dashboard se actualizo
- [ ] Probaste la alerta con `{"temperature": 45}` y llego el correo
- [ ] Hiciste `vagrant halt` + `vagrant up` y los datos seguían en `books`
- [ ] Nunca corriste `vagrant provision` durante la demo de persistencia