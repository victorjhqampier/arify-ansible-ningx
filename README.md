# Proxy Nginx Multi-Endpoint

Este proyecto configura la misma instancia EC2 como controlador Ansible y servidor Nginx.
El playbook esta preparado para escalar a muchos endpoints sin duplicar tareas.

## Archivo unico para cambios diarios

Para agregar o retirar endpoints, debe tocar solo este archivo:

```text
group_vars/nginx.yml
```

No debe editar normalmente:

- `playbook.yml`
- `templates/nginx.conf.j2`
- `templates/reverse-proxy.conf.j2`
- `inventory.ini`

## Agregar un endpoint

En `group_vars/nginx.yml`, copiar un bloque dentro de la lista `proxies`:

```yaml
- name: mi_servicio
  host: api.ejemplo.com
  scheme: https
  port: 443
  path_name: mi-servicio
  path_prefix: /mi-servicio/
  keepalive: 32
  ssl_verify: true
  ssl_verify_depth: 3
  connect_timeout: 10s
  send_timeout: 60s
  read_timeout: 60s
```

Reglas importantes:

- `name`: usar minusculas, numeros y guion bajo; debe empezar con letra.
- `host`: dominio destino sin `https://` y sin ruta.
- `scheme`: protocolo real del destino, `http` o `https`.
- `port`: puerto real del destino.
- `path_name`: ruta corta sin `/`; normalmente coincide con `path_prefix` sin barras.
- `path_prefix`: ruta local; siempre empieza y termina con `/`.
- `keepalive`: cantidad de conexiones persistentes al upstream.
- `ssl_verify` y `ssl_verify_depth`: obligatorios cuando `scheme` es `https`; no se usan en endpoints `http`.
- `connect_timeout`, `send_timeout`, `read_timeout`: tiempos explicitos para evitar comportamientos implicitos.

Ejemplo HTTP interno:

```yaml
- name: interno
  host: servicio.interno.local
  scheme: http
  port: 80
  path_name: interno
  path_prefix: /interno/
  keepalive: 16
  connect_timeout: 5s
  send_timeout: 30s
  read_timeout: 30s
```

## Retirar un endpoint

En `group_vars/nginx.yml`, eliminar el bloque completo del endpoint dentro de `proxies`.

Ejemplo:

```yaml
- name: keynua
  host: www.keynua.com
  scheme: https
  port: 443
  path_name: keynua
  path_prefix: /keynua/
  keepalive: 32
  ssl_verify: true
  ssl_verify_depth: 3
  connect_timeout: 10s
  send_timeout: 60s
  read_timeout: 60s
```

## Como funciona el mapeo

La solicitud local:

```text
http://localhost/ceptinel/v1/hola
```

se envia a:

```text
https://prod-monitoreo-clap.ceptinel.com/v1/hola
```

El prefijo `/ceptinel/` se elimina porque la plantilla usa `proxy_pass` con `/` al final.
El mismo comportamiento aplica para todos los endpoints declarados en `proxies`.

## Ejecucion

Desde la carpeta del proyecto:

```bash
sudo ansible-playbook -i inventory.ini playbook.yml
```

Tambien se puede usar el helper:

```bash
./relanzar.sh
```

## Validacion antes de ejecutar

```bash
ansible-playbook -i inventory.ini playbook.yml --syntax-check
ansible-playbook -i inventory.ini playbook.yml --tags validate
ansible-lint .
```

El playbook tambien valida en ejecucion:

- Que exista al menos un endpoint.
- Que cada endpoint tenga `name`, `host`, `scheme`, `port`, `path_name`, `path_prefix`, `keepalive` y timeouts.
- Que cada endpoint HTTPS tenga `ssl_verify` y `ssl_verify_depth`.
- Que no existan `name` o `path_prefix` duplicados.
- Que Nginx acepte la configuracion con `nginx -t`.
- Que los upstreams y locations queden cargados en `nginx -T`.

## Pruebas despues de ejecutar

```bash
curl -i http://localhost/ceptinel/
curl -i http://localhost/keynua/
```

Para inspeccionar la configuracion efectiva:

```bash
sudo nginx -T | grep -n -A 25 -B 5 "_backend"
sudo systemctl status nginx
```

## Logs

```bash
sudo tail -f /var/log/nginx/reverse-proxy-access.log
sudo tail -f /var/log/nginx/reverse-proxy-error.log
```

El access log incluye tiempos internos de conexion y respuesta del upstream.
