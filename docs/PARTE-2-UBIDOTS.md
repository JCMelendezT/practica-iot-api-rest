# Parte 2: Ubidots

## Que demuestra

Que los datos pueden vivir **fuera de la máquina**, en un servicio en la nube, y que para hablar con ese servicio hace falta una credencial personal. Ubidots agrega dos cosas que las otras partes no tienen: un limite de uso y un secreto.

Esta parte **no es un servidor**. No expone `/books` y no escucha ningun puerto. Es un cliente: lee sensores simulados y los publica en un dispositivo de Ubidots.

## Como obtener el token

El token es una credencial personal e intransferible. **Cada estudiante necesita el suyo**: no se comparte, no se pide prestado, no se publica.

En la consola de Ubidots:

1. Entra a tu cuenta en <https://platform.ubidots.com>.
2. Abre **Dispositivos** y selecciona tu dispositivo, o crealo si no existe. La etiqueta debe coincidir con la que usa el código: `machine`.
3. Abre la pestana **Ajustes** del dispositivo.
4. Copia el **Token de API**. Empieza con el prefijo `BBUS-` y es una cadena larga.

Después, exportalo en la terminal de la VM:

```bash
# (dentro de la VM) Exporta tu token en ESTA terminal.
export UBIDOTS_TOKEN=BBUS-pega-aqui-tu-token
```

El token queda en la memoria de la shell. Si abres otra terminal, tienes que exportarlo de nuevo.

### El archivo `.env`

En el host hay una plantilla, `.env.example`, con el token y la etiqueta del dispositivo:

```
UBIDOTS_TOKEN=BBUS-pega-aqui-tu-token
UBIDOTS_DEVICE_LABEL=machine
```

Si prefieres trabajar con un archivo en vez de exportar en cada terminal, crealo a partir de la plantilla:

```bash
# (host) Crea el archivo real a partir de la plantilla (Linux y macOS).
cp .env.example .env
```

```powershell
# (host) Crea el archivo real a partir de la plantilla (PowerShell en Windows).
copy .env.example .env
```

```bash
# (host) Abre el archivo y reemplaza el valor de ejemplo por tu token real.
# En Windows con Bloc de notas; en Linux puedes usar nano o vim.
notepad .env
```

| Punto | Detalle |
|---|---|
| Se sube `.env` al repositorio? | No. Esta en `.gitignore` |
| Qué sí se sube? | `.env.example`, que no tiene el valor real |
| Se usa `.env` dentro de la VM? | No hace falta: alcanza con `export` |
| Donde quedo la plantilla en la VM | En `/home/vagrant/practica.env.example` |

El código lee el token de la variable de entorno, nunca de un archivo:

```python
TOKEN = os.environ.get("UBIDOTS_TOKEN", "")
```

> Que decir: "El token no está escrito en el código. Se lee de una variable de entorno, y el único archivo del repositorio es la plantilla, sin el valor real. Además es personal: cada uno usa su token, porque la cuota de datos y los dispositivos están asociados a la cuenta."

## La cuota diaria: 4000 puntos de datos

El plan STEM de Ubidots permite **4000 puntos de datos por día**. Un punto de dato es una variable enviada en una petición.

El script envía 5 variables cada 10 segundos:

```
5 variables x 6 peticiones por minuto x 60 minutos = 1800 puntos por hora
1800 x 24 horas                                    = 43 200 puntos por dia
```

El cupo es de 4000. **Un día de ejecución continua agota la cuota y la supera por un factor de casi once.** Por eso el script está pensado para demostraciones cortas: correr uno o dos minutos, ver los widgets actualizarse y detenerlo con `Ctrl+C`.

Cuando se agota el cupo, la API empieza a responder con errores y el dashboard deja de actualizarse. La cuota se reinicia por periodo.

## Las cinco variables

El script genera valores aleatorios para simular sensores reales:

| Variable | Etiqueta | Rango simulado | Unidad |
|---|---|---|---|
| 1 | `temperature` | -10 a 50 | grados Celsius |
| 2 | `humidity` | 0 a 85 | porcentaje |
| 3 | `position` | punto GPS | ver abajo |
| 4 | `pressure` | 980 a 1040 | hectopascales (hPa) |
| 5 | `battery` | 0 a 100 | porcentaje |

Las variables 4 y 5 son las agregadas para esta versión de la práctica.

### La forma de `position`

`position` no es un número: es un objeto con un valor y un contexto. El contexto es lo que permite dibujar el punto en el mapa del dashboard:

```python
{variable_3: {"value": 1, "context": {"lat": lat, "lng": lng}}}
```

Las coordenadas se simulan alrededor de **Cali, Colombia**, con un margen de 0.05 grados:

```python
lat = 3.40 + random.uniform(-0.05, 0.05)
lng = -76.52 + random.uniform(-0.05, 0.05)
```

> Que decir: "La variable `position` es especial: no lleva un valor simple sino un valor y un contexto. El contexto tiene la latitud y la longitud, y es lo que permite que Ubidots lo muestre en un widget de mapa. Ahí se ve por que un dato no es solo un número: es un número más el significado que le da el contexto."

## Ejecutar el script

```bash
# (dentro de la VM) Entra a la carpeta de la Parte 2.
cd /home/vagrant/app/parte2-ubidots
```

```bash
# (dentro de la VM) Corre el cliente. Envia cada 10 segundos, sin parar.
python3 testUbidots.py
```

Cada vuelta imprime:

```
[INFO] Attemping to send data: {...}
[INFO] request made properly, your device is updated
[INFO] finished
```

Dejalo correr entre 60 y 120 segundos y detenelo con `Ctrl+C`. La librería `requests` ya está instalada por `provision/03-python.sh`, así que no hay nada que instalar antes.

### Si no exportaste el token

El script detecta la variable vacía antes de intentar nada, imprime el error en `stderr` y termina con código de salida 1:

```
[ERROR] Falta la variable de entorno UBIDOTS_TOKEN.
[ERROR] Configurala en esta terminal con:
[ERROR]     export UBIDOTS_TOKEN=BBUS-tu-token-completo
[ERROR] Mira docs/PARTE-2-UBIDOTS.md para como obtener el token.
```

Comprobación rapida antes de correr nada:

```bash
# (dentro de la VM) Verifica que la variable existe, sin imprimir su valor.
test -n "$UBIDOTS_TOKEN" && echo "token cargado"
```

## Las dos formas de autenticación

Ubidots acepta el token de dos maneras. La práctica muestra las dos para poder comparar.

### Forma 1: cabecera `X-Auth-Token` (la correcta)

```bash
# (dentro de la VM) Envia un valor con el token en la cabecera.
# DECIR: "Esta es la forma correcta. El token viaja en una cabecera HTTP."
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine" -H "X-Auth-Token: $UBIDOTS_TOKEN" -H "Content-Type: application/json" -d '{"temperature": 25}'
```

### Forma 2: parámetro `?token=` en la URL

```bash
# (dentro de la VM) La misma peticion con el token como parametro de la query string.
# DECIR: "Esta forma también funciona, pero noten que la URL va entrecomillada: si no,
# el shell interpretaria el ampersand."
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine?token=$UBIDOTS_TOKEN" -H "Content-Type: application/json" -d '{"temperature": 25}'
```

Con el token escrito a mano, la URL completa queda así:

```bash
# (dentro de la VM) La URL con el token incrustado, tal como queda en el historial del shell.
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine?token=BBUS-aqui-va-tu-token" -H "Content-Type: application/json" -d '{"temperature": 25}'
```

| Criterio | Cabecera `X-Auth-Token` | Parámetro `?token=` |
|---|---|---|
| Seguridad | Recomendada | Funciona, pero es peor |
| Queda en el historial del shell? | No, queda como `$UBIDOTS_TOKEN` | Si, completo |
| Queda en los logs del servidor? | No aparece en la URL | Si aparece |
| Se puede cachear mal? | No | Si, la URL completa se cachea |
| Uso en la práctica | La que usa `testUbidots.py` | Se muestra para comparar |

> Que decir: "Las dos funcionan, y esa es la razon de ser de la parte 2. La diferencia es de seguridad, no de funcionalidad. En la forma con `?token=` el secreto queda escrito en la línea de comandos, sobrevive en el historial del shell y aparece en los logs del servidor. La forma correcta es la cabecera."

## Leer el dato de vuelta

El sufijo `lv` significa **last value**: devuelve únicamente el dato más reciente, no el historico.

```bash
# (dentro de la VM) Lee el ultimo valor de la temperatura.
# DECIR: "Asi leo de vuelta lo que el sensor acaba de publicar."
curl -s -H "X-Auth-Token: $UBIDOTS_TOKEN" "https://industrial.api.ubidots.com/api/v1.6/devices/machine/temperature/lv"
```

Cambiando `temperature` por cualquiera de las otras cuatro etiquetas se lee esa variable.

## Disparar la alerta por correo

Las alertas se configuran en la consola de Ubidots como reglas: si una variable supera un umbral, se envía un correo. En esta práctica la regla es **temperatura mayor a 40**.

El problema de la demostración es que el script genera temperaturas entre -10 y 50 de forma aleatoria, así que puede pasar mucho tiempo sin superar el umbral.

La solución es enviar el valor directamente:

```bash
# (dentro de la VM) Envia 45 grados, por encima del umbral de 40.
# DECIR: "En vez de esperar a que un sensor aleatorio pase de 40, que puede no pasar nunca,
# mando yo el valor que dispara la alerta."
curl -i -X POST "https://industrial.api.ubidots.com/api/v1.6/devices/machine" -H "X-Auth-Token: $UBIDOTS_TOKEN" -H "Content-Type: application/json" -d '{"temperature": 45}'
```

Una vez llega el correo, se puede decir que la parte está cerrada: el dato salio de la VM, se publicó en un servicio externo, y ese servicio evaluo una regla y me notifico.

## Verlo en el dashboard

En la consola de Ubidots, dentro del dispositivo `machine`:

| Widget | Que muestra |
|---|---|
| Gráfico de `temperature` | La serie de temperatura, con el punto que acaba de llegar en 45 |
| Gráfico de `humidity` | La serie de humedad |
| Gráfico de `pressure` | La serie de presión |
| Gráfico de `battery` | La serie de batería |
| Widget de mapa | El punto de `position`, dibujado con el contexto GPS |
| Historial de eventos | Cada petición recibida, con su fecha |

> Que decir: "En el dashboard veo las cinco variables en gráficos, y el punto en el mapa por el contexto GPS. Esta es la parte de la práctica donde los datos dejan de estar en mi computadora y quedan en un servicio de terceros, con su cuota, su credencial y su disponibilidad."

## Lo que hay que saber explicar

| Tema | Que decir |
|---|---|
| Token | Credencial personal, se lee de `UBIDOTS_TOKEN`, nunca en el código ni en el repositorio |
| Cuota | 4000 puntos de datos por día; el script envía 5 cada 10 s, o sea 1800 por hora |
| Intervalo | 10 segundos entre envios, para cuidar el cupo |
| Reintentos | El bucle reintenta mientras el status sea >= 400, con `time.sleep(1)` entre intentos |
| Contexto | `position` lleva `value` más un `context` con `lat` y `lng`, con coordenadas alrededor de Cali |
| Autenticación | Cabecera `X-Auth-Token` frente a `?token=`; la cabecera no deja el secreto en la URL |
| Lectura | `GET /devices/machine/<variable>/lv` devuelve el último valor |

## Siguiente paso

La Parte 2 depende de un servicio externo y de una cuota. La Parte 3 elimina las dos cosas: guarda los datos en un servidor local que uno mismo controla.

Continua con [PARTE-3-MYSQL.md](PARTE-3-MYSQL.md).
