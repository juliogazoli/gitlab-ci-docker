#!/bin/bash

echo "=== Configuração do GitLab CI/CD com Docker ==="

# Verificar se Docker e Docker Compose estão instalados
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado!"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose não está instalado!"
    exit 1
fi

# Criar diretório do projeto
mkdir -p gitlab-cicd
cd gitlab-cicd

# Verificar se já existe um docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "⚠️  docker-compose.yml já existe. Fazendo backup..."
    mv docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
fi

echo "📝 Criando docker-compose.yml..."

# Adicionar entrada no /etc/hosts
echo "🔧 Configurando /etc/hosts..."
if ! grep -q "gitlab.local" /etc/hosts; then
    echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts
    echo "✅ Entrada gitlab.local adicionada ao /etc/hosts"
else
    echo "✅ Entrada gitlab.local já existe no /etc/hosts"
fi

# Subir os containers
echo "🚀 Iniciando containers do GitLab..."
docker-compose up -d

echo "⏳ Aguardando GitLab inicializar (isso pode demorar alguns minutos)..."
echo "📍 GitLab estará disponível em: http://gitlab.local"

# Aguardar o GitLab ficar disponível
timeout=300
counter=0
while [ $counter -lt $timeout ]; do
    if curl -s http://gitlab.local > /dev/null 2>&1; then
        echo "✅ GitLab está rodando!"
        break
    fi
    echo "⏳ Aguardando... ($counter/$timeout)"
    sleep 10
    counter=$((counter + 10))
done

if [ $counter -ge $timeout ]; then
    echo "❌ Timeout aguardando GitLab inicializar"
    exit 1
fi

# Obter senha inicial do root
echo "🔑 Obtendo senha inicial do usuário root..."
ROOT_PASSWORD=$(docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password 2>/dev/null | cut -d: -f2 | tr -d ' ')

if [ -n "$ROOT_PASSWORD" ]; then
    echo "✅ Senha do usuário root: $ROOT_PASSWORD"
    echo "💾 Salvando credenciais em credentials.txt"
    echo "Usuário: root" > credentials.txt
    echo "Senha: $ROOT_PASSWORD" >> credentials.txt
    echo "URL: http://gitlab.local" >> credentials.txt
else
    echo "❌ Não foi possível obter a senha do root"
fi

echo ""
echo "=== Próximos Passos ==="
echo "1. Acesse http://gitlab.local"
echo "2. Login com usuário 'root' e a senha fornecida acima"
echo "3. Execute o script de configuração do runner: ./configure-runner.sh"
echo ""
echo "=== Comandos Úteis ==="
echo "• Ver logs: docker-compose logs -f gitlab"
echo "• Parar: docker-compose down"
echo "• Reiniciar: docker-compose restart"
echo "• Status: docker-compose ps"
