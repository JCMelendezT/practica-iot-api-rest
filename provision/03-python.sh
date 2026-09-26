#!/bin/bash
# =============================================================================
# 03 - Dependencias de Python
#
# LAS VERSIONES ESTAN PINNEADAS A PROPOSITO. No las actualices sin probar.
#
#   Flask 2.3.3 ............ 2.3+ exige un Jinja/werkzeug compatible.
#                             Sin el pin, la app levanta con errores de
#                             import al arrancar.
#   Flask-MySQLdb 1.0.1 .... esta version usa mysqlclient (extension en C).
#                             Las versiones mas nuevas cambian a PyMySQL
#                             (Python puro), que no negocia bien la
#                             autenticacion caching_sha2_password de MySQL 8.
#                             Con una version sin pin, mysql.connection queda
#                             en None y TODOS los endpoints devuelven 500 con
#                             "NoneType has no attribute 'cursor'".
#
#   mysqlclient (dependencia transitiva) se compila: por eso 01-system-deps.sh
#   instala build-essential, pkg-config, python3-dev y default-libmysqlclient-dev.
#   Si 01 falla, este script falla.
# =============================================================================
set -e

echo "[03] Instalando dependencias de Python"

# --break-system-packages: Ubuntu 22.04 no lo exige (empezó en 23.04), pero
# mantiene el script funcionando si alguien copia esto a una distro más nueva.
sudo pip3 install --no-cache-dir \
  "Flask==2.3.3" \
  "Flask-MySQLdb==1.0.1" \
  "requests" \
  || sudo pip3 install --no-cache-dir --break-system-packages \
  "Flask==2.3.3" \
  "Flask-MySQLdb==1.0.1" \
  "requests"

echo "[03] Verificando que la extension en C se compilo"
python3 - <<'PY'
import importlib.metadata as meta
import MySQLdb  # extension en C: si esto importa, compiló bien
import requests, flask, flask_mysqldb

print("[03] Flask          ", flask.__version__)
print("[03] mysqlclient    ", meta.version("mysqlclient"), "->", MySQLdb.version_info)
print("[03] Flask-MySQLdb  ", meta.version("Flask-MySQLdb"))
print("[03] requests       ", requests.__version__)

# Verifica tambien que la app puede abrir la conexion a MySQL de verdad.
import MySQLdb as _db
c = _db.connect(host="localhost", user="root", password="root", database="myflaskapp")
cur = c.cursor()
cur.execute("SELECT COUNT(*) FROM books")
print("[03] conexion a myflaskapp OK, libros en la tabla:", cur.fetchone()[0])
c.close()
PY

echo "[03] Listo"
