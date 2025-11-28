#!/bin/bash

# ==============================
# Script: atualiza_certificados.sh
# Objetivo: Atualizar certificados SSL no servidor
# ==============================

# Links diretos para download dos arquivos
BUNDLE_URL="https://downloads.hsprevent.com.br/bundle.crt"
PRIVATE_URL="https://downloads.hsprevent.com.br/STAR_hsprevent_com_br.private.pem"

# Diretórios possíveis
DIRS=(
    "/certificates/ssl"
    "/certificados/ssl"
    "/certificates/ssl24"
    "/certificados/ssl24"
)

# Nome dos arquivos (mantendo bundle.crt como padrão)
BUNDLE_FILE="bundle.crt"
PRIVATE_FILE="STAR_hsprevent_com_br.private.pem"

# Função para encontrar diretório válido
find_target_dir() {
    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Localiza diretório
TARGET_DIR=$(find_target_dir)
if [ -z "$TARGET_DIR" ]; then
    echo "Nenhum diretório válido encontrado!"
    exit 1
fi

echo "Diretório encontrado: $TARGET_DIR"

# Backup dos arquivos antigos
if [ -f "$TARGET_DIR/$BUNDLE_FILE" ]; then
    mv "$TARGET_DIR/$BUNDLE_FILE" "$TARGET_DIR/old-$BUNDLE_FILE"
    echo "Backup do $BUNDLE_FILE realizado."
fi

if [ -f "$TARGET_DIR/$PRIVATE_FILE" ]; then
    mv "$TARGET_DIR/$PRIVATE_FILE" "$TARGET_DIR/old-$PRIVATE_FILE"
    echo "Backup do $PRIVATE_FILE realizado."
fi

# Download dos novos arquivos
echo "Baixando novos certificados..."
curl -s -o "$TARGET_DIR/$BUNDLE_FILE" "$BUNDLE_URL"
curl -s -o "$TARGET_DIR/$PRIVATE_FILE" "$PRIVATE_URL"

# Validação pós-download
if [ -f "$TARGET_DIR/$BUNDLE_FILE" ] && [ -f "$TARGET_DIR/$PRIVATE_FILE" ]; then
    echo "Certificados atualizados com sucesso!"
else
    echo "Erro ao atualizar certificados!"
    exit 1
fi

# Ajuste no nginx.conf (opcional, caso ainda exista referência antiga)
NGINX_CONF="/usr/local/openresty/nginx/conf/nginx.conf"
if [ -f "$NGINX_CONF" ]; then
    echo "Verificando nginx.conf..."
    # Remove referências antigas se existirem
    sed -i 's/bundle2025\.crt/bundle.crt/g' "$NGINX_CONF"
    echo "Substituição concluída."
else
    echo "Arquivo nginx.conf não encontrado em $NGINX_CONF"
fi

# Reiniciar serviços
echo "Reiniciando serviços..."
systemctl restart openresty.service && echo "Nginx reiniciado." || echo "Nginx não encontrado."
systemctl restart apache2.service && echo "Apache reiniciado." || echo "Apache não encontrado."

echo "Processo concluído"
