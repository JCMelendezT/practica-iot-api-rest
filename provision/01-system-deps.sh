#!/bin/bash
# =============================================================================
# 01 - Dependencias de sistema
#
# MySQL y Node compilan/enlazan contra estas librerias. Sin este script,
# Flask-MySQLdb y mysql2 fallan al instalarse.
# =============================================================================
set -e

echo "[01] Instalando dependencias de sistema"

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential \
  pkg-config \
  python3-dev \
  python3-pip \
  default-libmysqlclient-dev \
  mysql-client \
  curl \
  ca-certificates \
  git

echo "[01] Listo"
