import os
import sys
import time
import requests
import math
import random

# El token NUNCA va hardcodeado: es una credencial personal de cada estudiante
# y sube a un repositorio publico. Se lee del entorno.
# Configuracion (una vez por terminal):
#     export UBIDOTS_TOKEN=BBUS-tu-token-completo
# Esta guia explica como obtenerlo: docs/PARTE-2-UBIDOTS.md
TOKEN = os.environ.get("UBIDOTS_TOKEN", "")

DEVICE_LABEL = "machine"          # Etiqueta del dispositivo
VARIABLE_LABEL_1 = "temperature"  # Variable 1
VARIABLE_LABEL_2 = "humidity"     # Variable 2
VARIABLE_LABEL_3 = "position"     # Variable 3 (con contexto GPS)
VARIABLE_LABEL_4 = "pressure"     # NUEVA variable 4: presion (hPa)
VARIABLE_LABEL_5 = "battery"      # NUEVA variable 5: bateria (%)
SEND_INTERVAL = 10                # Segundos entre envios (cuida el cupo diario de STEM)


def build_payload(variable_1, variable_2, variable_3, variable_4, variable_5):
    # Valores aleatorios para simular sensores
    value_1 = random.randint(-10, 50)       # temperatura C
    value_2 = random.randint(0, 85)         # humedad %
    value_4 = random.randint(980, 1040)     # presion hPa
    value_5 = random.randint(0, 100)        # bateria %

    # Coordenadas GPS aleatorias alrededor de Cali
    lat = 3.40 + random.uniform(-0.05, 0.05)
    lng = -76.52 + random.uniform(-0.05, 0.05)

    payload = {variable_1: value_1,
               variable_2: value_2,
               variable_3: {"value": 1, "context": {"lat": lat, "lng": lng}},
               variable_4: value_4,
               variable_5: value_5}
    return payload


def post_request(payload):
    url = "https://industrial.api.ubidots.com"
    url = "{}/api/v1.6/devices/{}".format(url, DEVICE_LABEL)
    headers = {"X-Auth-Token": TOKEN, "Content-Type": "application/json"}

    status = 400
    attempts = 0
    while status >= 400 and attempts <= 5:
        req = requests.post(url=url, headers=headers, json=payload)
        status = req.status_code
        attempts += 1
        time.sleep(1)

    if status >= 400:
        print("[ERROR] Could not send data after 5 attempts, please check "
              "your token credentials and internet connection")
        print("[ERROR] Last response:", status, req.text)
        return False

    print("[INFO] request made properly, your device is updated")
    return True


def main():
    payload = build_payload(VARIABLE_LABEL_1, VARIABLE_LABEL_2, VARIABLE_LABEL_3,
                            VARIABLE_LABEL_4, VARIABLE_LABEL_5)
    print("[INFO] Attemping to send data:", payload)
    post_request(payload)
    print("[INFO] finished")


if __name__ == '__main__':
    # Falla rapido y con un mensaje util, en vez de repetir 5 veces un 401
    # y dejar al estudiante pensando que su internet esta roto.
    if not TOKEN:
        print("[ERROR] Falta la variable de entorno UBIDOTS_TOKEN.", file=sys.stderr)
        print("[ERROR] Configurala en esta terminal con:", file=sys.stderr)
        print("[ERROR]     export UBIDOTS_TOKEN=BBUS-tu-token-completo", file=sys.stderr)
        print("[ERROR] Mira docs/PARTE-2-UBIDOTS.md para como obtener el token.",
              file=sys.stderr)
        sys.exit(1)

    while (True):
        main()
        time.sleep(SEND_INTERVAL)
