#!/bin/bash
# =============================================================================
# 04 - Node.js + dependencias del Desafio en Express
#
# Ubuntu 22.04 viene con Node 12, y Express 5 exige Node >= 18. Por eso se
# instala Node 22 desde el repositorio oficial de NodeSource.
#
# `npm ci` (y no `npm install`) porque instala EXACTAMENTE lo que dice
# package-lock.json: mismo Express, mismo mysql2, en cualquier maquina.
# =============================================================================
set -e

NODE_APP_DIR="/home/vagrant/app/desafio-node"

echo "[04] Instalando Node.js 22 (NodeSource)"

if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" -lt 18 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
else
  echo "[04] Node ya instalado y con version suficiente: $(node -v)"
fi

echo "[04] Instalando dependencias del proyecto Node"
if [ ! -f "${NODE_APP_DIR}/package.json" ]; then
  echo "[04] ERROR: no se encontro ${NODE_APP_DIR}/package.json" >&2
  exit 1
fi
cd "$NODE_APP_DIR"
npm ci --no-audit --no-fund

echo "[04] Verificando"
node --version
npm --version
node -e "console.log('[04] express  ', require('express/package.json').version);
         console.log('[04] mysql2   ', require('mysql2/package.json').version)"

echo "[04] Listo"
