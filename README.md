1. Preparação dos Arquivos
Primeiro, salve os arquivos que criei:

``` sh
# Criar diretório para o projeto
mkdir gitlab-cicd
cd gitlab-cicd

# Salvar o docker-compose.yml (copie o conteúdo do primeiro artifact)
nano docker-compose.yml

``` sh
# Salvar o script de setup (copie o conteúdo do segundo artifact)
nano setup-gitlab.sh

# Salvar o script de configuração do runner (copie o conteúdo do terceiro artifact)
nano configure-runner.sh
```

2. Dar Permissão de Execução aos Scripts
``` sh
bashchmod +x setup-gitlab.sh
chmod +x configure-runner.sh

3. Executar o Setup Inicial
``` sh
# Executar o script principal
./setup-gitlab.sh
```

Este script vai:

✅ Verificar se Docker está instalado  
📁 Criar os volumes necessários  
🌐 Adicionar gitlab.local ao /etc/hosts  
🚀 Subir todos os containers  
⏳ Aguardar o GitLab inicializar  
🔑 Obter a senha inicial do usuário   

4. Primeiro Acesso ao GitLab
Após o script terminar:

Acesse: http://gitlab.local
Login:

Usuário: root
Senha: (será exibida no terminal ou salva em credentials.txt)

5. Configurar o Runner
``` sh
# Executar após fazer login no GitLab
./configure-runner.sh
```

Para obter o token de registro:

No GitLab, vá em Admin Area → Runners
Copie o Registration Token
Cole quando o script solicitar

6. Comandos Úteis
``` sh
# Ver status dos containers
docker-compose ps

# Ver logs do GitLab
docker-compose logs -f gitlab

# Ver logs do Runner
docker-compose logs -f gitlab-runner

# Parar tudo
docker-compose down

# Reiniciar
docker-compose restart

# Parar e remover volumes (CUIDADO: apaga dados)
docker-compose down -v
```

7. Solução de Problemas
Se o GitLab demorar muito para inicializar:
``` sh
# Verificar logs
docker-compose logs gitlab

# Verificar recursos do sistema
docker stats

# Se necessário, aumentar memória no docker-compose.yml
# Adicione na seção do gitlab:
# deploy:
#   resources:
#     limits:
#       memory: 4G
```

8. Testar CI/CD
Crie um arquivo .gitlab-ci.yml no seu repositório:
``` yml
yamlstages:
  - test
  - build

test_job:
  stage: test
  script:
    - echo "Executando testes..."
    - echo "Teste passou!"

build_job:
  stage: build
  script:
    - echo "Construindo aplicação..."
    - echo "Build concluído!"
```

O GitLab está pronto para uso quando você conseguir acessar http://gitlab.local e fazer login!

Diagnóstico de Problemas
Se ainda tiver problemas, execute estes comandos para diagnóstico:
``` sh
# Ver logs do runner
docker-compose logs gitlab-runner

# Ver redes disponíveis
docker network ls | grep gitlab

# Testar conectividade manual
docker exec gitlab-runner ping -c 3 gitlab.local

# Ver configuração do runner
docker exec gitlab-runner cat /etc/gitlab-runner/config.toml
```