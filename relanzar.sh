#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

sudo ansible-playbook -i inventory.ini playbook.yml

echo
echo "Validando Nginx..."
sudo nginx -t

echo
echo "Configuracion de upstreams cargada:"
sudo nginx -T 2>&1 | grep -n -A 35 -B 5 "_backend" || true

echo
echo "Pruebas locales:"
echo "El playbook probo todos los endpoints declarados en group_vars/nginx.yml."
