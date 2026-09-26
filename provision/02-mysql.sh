#!/bin/bash
# =============================================================================
# 02 - MySQL Server + base de datos de la practica
#
# Deja MySQL 8 como lo usa la practica:
#   - usuario root@localhost con password 'root' (caching_sha2_password)
#   - bind-address en 0.0.0.0 (ver nota de seguridad al final)
#   - base myflaskapp con la tabla books y 2 registros semilla
#
# IDEMPOTENTE: se puede volver a correr con `vagrant provision`.
# OJO: re-correr este script BORRA y recrea la tabla books (reset total).
# Para conservar los datos entre reinicios usá `vagrant halt` + `vagrant up`.
# =============================================================================
set -e

MYSQL_APP_DIR="/home/vagrant/app/parte3-mysql"
MYSQL_INIT_SQL="${MYSQL_APP_DIR}/init.sql"

echo "[02] Instalando MySQL Server"

# Preseed: fija la password de root durante la instalacion.
# El ALTER USER de mas abajo es lo que realmente lo garantiza.
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mysql-server

# `enable` (no solo `start`): MySQL tiene que levantar solo despues de un
# `vagrant up`. Es lo que demuestra la parte de persistencia.
sudo systemctl enable mysql.service
sudo systemctl restart mysql.service

echo "[02] Configurando root@localhost con password 'root'"
# Hay dos caminos posibles segun como haya quedado la instalacion:
#
#   A) El preseed de arriba funciono -> root ya tiene password 'root' y el
#      plugin caching_sha2_password. En ese caso `mysql -u root` SIN password
#      falla, y hay que pasar la password.
#   B) El preseed fue ignorado -> root sigue con auth_socket (login por usuario
#      del sistema operativo) y todavia no tiene password.
#
# Se cubren los dos y se termina siempre en el mismo estado, que es el que
# espera la app: root@localhost / 'root' / caching_sha2_password.
if sudo mysql --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; then
  echo "[02]   root aun usa auth_socket: asignando password"
  sudo mysql --protocol=socket -u root <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'root';
FLUSH PRIVILEGES;
SQL
else
  echo "[02]   el preseed funciono: normalizando el plugin a caching_sha2"
  sudo mysql -u root -proot -e "
    ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'root';
    FLUSH PRIVILEGES;"
fi

echo "[02] Habilitando escucha en la red privada de Vagrant"
# 0.0.0.0 permite conectarse desde Windows (por ejemplo, MySQL Workbench).
# Solo existe el usuario root@localhost, asi que un cliente remoto que intente
# entrar como root igual es rechazado: esto NO abre root al exterior.
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql.service

echo "[02] Creando y llenando la base de datos"
if [ ! -f "$MYSQL_INIT_SQL" ]; then
  echo "[02] ERROR: no se encontro $MYSQL_INIT_SQL" >&2
  echo "[02] El provisioner 'file' deberia haber copiado app/ antes de este script." >&2
  exit 1
fi
sudo mysql -u root -proot < "$MYSQL_INIT_SQL"

echo "[02] Verificando instalacion"
sudo mysql -u root -proot -e "SELECT COUNT(*) AS libros FROM myflaskapp.books;"

echo "[02] Listo"
