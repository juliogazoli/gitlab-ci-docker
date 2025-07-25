#!/bin/bash

echo "=== Configuração do GitLab Runner ==="

# Verificar se o GitLab está rodando
if ! curl -s http://gitlab.local > /dev/null; then
    echo "❌ GitLab não está acessível em http://gitlab.local"
    echo "Execute primeiro: ./setup-gitlab.sh"
    exit 1
fi

# Verificar se o container gitlab-runner está rodando
if ! docker ps | grep -q "gitlab-runner"; then
    echo "❌ Container gitlab-runner não está rodando!"
    echo "Execute: docker-compose up -d"
    exit 1
fi

# Verificar se a rede existe
NETWORK_NAME=$(docker network ls --format "{{.Name}}" | grep gitlab)
if [ -z "$NETWORK_NAME" ]; then
    echo "❌ Rede do GitLab não encontrada!"
    echo "Execute: docker-compose down && docker-compose up -d"
    exit 1
fi

echo "✅ Rede encontrada: $NETWORK_NAME"

echo "📋 Para configurar o runner, você precisa obter o registration token:"
echo "1. Acesse http://gitlab.local"
echo "2. Faça login como admin (usuário: root)"
echo "3. Vá em Admin Area > Runners (ou /admin/runners)"
echo "4. Na seção 'Set up a shared runner manually'"
echo "5. Copie o registration token"
echo ""
echo "💡 Dica: O token geralmente começa com 'glrt-' ou similar"
echo ""

read -p "🔑 Cole o registration token aqui: " REGISTRATION_TOKEN

if [ -z "$REGISTRATION_TOKEN" ]; then
    echo "❌ Token não pode estar vazio!"
    exit 1
fi

echo "🔧 Registrando runner..."

# Primeiro, limpar registros antigos se existirem
docker exec gitlab-runner gitlab-runner unregister --all-runners 2>/dev/null || true

# Registrar o runner de forma não interativa
docker exec gitlab-runner gitlab-runner register \
    --non-interactive \
    --url "http://gitlab.local" \
    --registration-token "$REGISTRATION_TOKEN" \
    --executor "docker" \
    --docker-image "alpine:latest" \
    --description "Docker Runner - CI/CD" \
    --tag-list "docker,linux,shared" \
    --run-untagged="true" \
    --locked="false" \
    --access-level="not_protected" \
    --docker-privileged="true" \
    --docker-volumes="/var/run/docker.sock:/var/run/docker.sock" \
    --docker-network-mode="$NETWORK_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Runner registrado com sucesso!"
    
    echo "🔧 Aplicando configurações adicionais..."
    
    # Obter o nome da rede dinamicamente
    NETWORK_NAME=$(docker network ls --format "{{.Name}}" | grep gitlab | head -1)
    
    # Editar o config.toml para corrigir configurações
    docker exec gitlab-runner bash -c "
    # Backup do config original
    cp /etc/gitlab-runner/config.toml /etc/gitlab-runner/config.toml.backup
    
    # Modificar configurações
    sed -i 's|url = \"http://gitlab:80\"|url = \"http://gitlab.local\"|g' /etc/gitlab-runner/config.toml
    sed -i 's|network_mode = \".*\"|network_mode = \"$NETWORK_NAME\"|g' /etc/gitlab-runner/config.toml
    sed -i 's|pull_policy = \".*\"|pull_policy = \"if-not-present\"|g' /etc/gitlab-runner/config.toml
    "
    
    echo "🔄 Reiniciando runner para aplicar configurações..."
    docker restart gitlab-runner
    
    # Aguardar o runner reiniciar
    sleep 10
    
    echo "🔍 Verificando conectividade..."
    
    # Teste de conectividade básica
    if docker exec gitlab-runner ping -c 1 gitlab.local >/dev/null 2>&1; then
        echo "✅ Conectividade com GitLab: OK"
    else
        echo "⚠️  Problema de conectividade detectado"
        echo "🔧 Aplicando correção de DNS..."
        
        # Adicionar entrada DNS no container do runner
        docker exec gitlab-runner bash -c "
        if ! grep -q 'gitlab.local' /etc/hosts; then
            echo '$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' gitlab) gitlab.local' >> /etc/hosts
        fi
        "
    fi
    
    echo "✅ Runner configurado e reiniciado com sucesso!"
    
else
    echo "❌ Erro ao registrar runner"
    echo "🔍 Diagnóstico:"
    echo "• Verificando conectividade..."
    docker exec gitlab-runner ping -c 1 gitlab.local
    echo "• Verificando rede..."
    docker network ls | grep gitlab
    exit 1
fi

echo ""
echo "=== ✅ Runner Configurado com Sucesso ==="
echo "• Nome: Docker Runner - CI/CD"
echo "• Tags: docker, linux, shared"
echo "• Executor: Docker"
echo "• Imagem padrão: alpine:latest"
echo "• Modo privilegiado: Habilitado"
echo "• Docker socket: Montado"
echo "• Rede: $NETWORK_NAME"
echo ""
echo "🔗 Verificar runners em: http://gitlab.local/admin/runners"
echo ""
echo "🧪 Teste seu runner com este .gitlab-ci.yml:"
echo "---"
echo "test:"
echo "  script:"
echo "    - echo 'Hello from GitLab CI/CD!'"
echo "    - whoami"
echo "    - pwd"
echo "    - ls -la"
echo "---"
echo ""
echo "🔧 Se ainda tiver problemas, execute:"
echo "docker-compose logs gitlab-runner"
