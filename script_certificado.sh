#!/bin/bash
set -euo pipefail

BUNDLE_URL="https://downloads.hsprevent.com.br/bundle.crt"
PRIVATE_URL="https://downloads.hsprevent.com.br/STAR_hsprevent_com_br.private.pem"

DIRS=(
  "/certificates/ssl"
  "/certificados/ssl"
  "/certificates/ssl24"
  "/certificados/ssl24"
  "/certificates/old"
  "/certificados/old"
  "/certificates"
  "/certificados"
  "/certificates/route"
)

BUNDLE_FILE="bundle.crt"
PRIVATE_FILE="STAR_hsprevent_com_br.private.pem"

find_target_dir() {
  for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

TARGET_DIR=$(find_target_dir || true)
if [[ -z "${TARGET_DIR:-}" ]]; then
  echo "Nenhum diretório válido encontrado!" >&2
  exit 1
fi
echo "Diretório encontrado: $TARGET_DIR"

# Garantir permissões de escrita
if [[ ! -w "$TARGET_DIR" ]]; then
  echo "Diretório $TARGET_DIR não é gravável." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"

backup_if_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    mv "$path" "${path}.old-${timestamp}"
    echo "Backup de $(basename "$path") realizado em ${path}.old-${timestamp}."
  fi
}

backup_if_exists "$TARGET_DIR/$BUNDLE_FILE"
backup_if_exists "$TARGET_DIR/$PRIVATE_FILE"

download_file() {
  local url="$1"
  local dest="$2"
  echo "Baixando: $url -> $dest"
  # -f fail on HTTP errors, -S show errors, -L follow redirects, retry 3
  curl -fSL --retry 3 --connect-timeout 10 --max-time 120 -o "$dest" "$url"
}

download_file "$BUNDLE_URL" "$TARGET_DIR/$BUNDLE_FILE"
download_file "$PRIVATE_URL" "$TARGET_DIR/$PRIVATE_FILE"

# Valida tamanho (>0) e conteúdo básico
for f in "$TARGET_DIR/$BUNDLE_FILE" "$TARGET_DIR/$PRIVATE_FILE"; do
  if [[ ! -s "$f" ]]; then
    echo "Arquivo $f está vazio ou não existe!" >&2
    exit 1
  fi
done

if ! grep -qE '-----BEGIN (CERTIFICATE|RSA PRIVATE KEY|PRIVATE KEY)-----' "$TARGET_DIR/$PRIVATE_FILE"; then
  echo "Conteúdo inesperado em $PRIVATE_FILE (não parece chave privada PEM)." >&2
  exit 1
fi

echo "Certificados atualizados com sucesso!"

# Ajuste no nginx.conf
NGINX_PATHS=(
  "/usr/local/openresty/nginx/conf/nginx.conf"
  "/etc/nginx/nginx.conf"
)

FOUND_CONF=""
for path in "${NGINX_PATHS[@]}"; do
  if [[ -f "$path" ]]; then
    FOUND_CONF="$path"
    break
  fi
done

if [[ -n "$FOUND_CONF" ]]; then
  echo "Ajustando nginx.conf em $FOUND_CONF..."
  sed -i 's/bundle2025\.crt/bundle.crt/g' "$FOUND_CONF"
  echo "Substituição concluída."
else
  echo "Arquivo nginx.conf não encontrado nos caminhos padrão."
fi

# Reiniciar serviços (não falhar se não existirem)
echo "Reiniciando serviços..."
if systemctl restart openresty.service 2>/dev/null; then
  echo "Nginx/OpenResty reiniciado."
else
  echo "OpenResty não encontrado."
fi

if systemctl restart apache2.service 2>/dev/null; then
  echo "Apache reiniciado."
else
  echo "Apache não encontrado."
fi
