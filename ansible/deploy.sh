#!/bin/bash

set -e

# Ir al directorio del script
cd "$(dirname "$0")"

echo "🚀 Ejecutando playbooks iniciales de Ansible..."

# Instalar Docker en todas las máquinas virtuales
echo "🔧 Instalando Docker en todas las VMs..."
#ansible-playbook -i inventory/hosts.ini playbooks/install_docker.yml

# Esperar un momento para asegurar que Docker esté listo
sleep 10

# Implementar microservicios
echo "🚢 Desplegando microservicios..."
# ansible-playbook -i inventory/hosts.ini playbooks/run_container.yml

# Obtener la IP de CI/Jenkins desde el archivo secrets.yml
ci_vm_ip=$(grep "ci_vm_ip" inventory/secrets.yml | awk -F': ' '{print $2}' | awk '{print $1}' | tr -d '"')

if [[ -z "$ci_vm_ip" ]]; then
  echo "❌ No se encontró la IP de la VM de CI en inventory/secrets.yml"
  exit 1
fi

echo "🔍 Usando IP de CI/Jenkins: $ci_vm_ip"



# Implementar SonarQube
echo "📊 Desplegando SonarQube..."
#ansible-playbook -i inventory/hosts.ini playbooks/deploy_sonarqube.yml

# Esperar a que SonarQube esté listo
echo "⏳ Esperando que SonarQube esté listo en http://$ci_vm_ip:9000..."

# Tiempo máximo de espera (en segundos)
timeout=180
elapsed=0
sleep 60  # Dar tiempo inicial para que el contenedor inicie completamente

# Intentar hacer health check hasta que esté listo
while true; do
  status=$(curl -s -u admin:admin "http://$ci_vm_ip:9000/api/system/health" 2>/dev/null | grep -o '"health":"[^"]*"' || echo "")

  if [[ "$status" == '"health":"GREEN"' ]]; then
    echo "✅ SonarQube está listo."
    break
  fi

  if (( elapsed >= timeout )); then
    echo "❌ SonarQube no se levantó después de $timeout segundos."
    echo "Última respuesta del servidor: $status"
    echo "Continuando de todos modos, pero es posible que necesites verificar manualmente."
    break
  fi

  echo "⌛ Sonar aún no está listo... esperando 10s más (tiempo transcurrido: ${elapsed}s)"
  sleep 10
  ((elapsed+=10))
done

echo "🔐 Preparando entorno Sonar para Jenkins..."

# Cambiar la contraseña por defecto de SonarQube
echo "🔄 Cambiando contraseña por defecto de Sonar..."
curl -s -X POST -u admin:admin "http://$ci_vm_ip:9000/api/users/change_password" \
  -d "login=admin" \
  -d "previousPassword=admin" \
  -d "password=MiPasswordSegura123!"

# Generar token de SonarQube para Jenkins
echo "🔑 Generando token para Jenkins..."
token_response=$(curl -s -u "admin:MiPasswordSegura123!" \
  -X POST "http://$ci_vm_ip:9000/api/user_tokens/generate" \
  -d "name=jenkins-token")

# Extraer el valor del token
sonar_token=$(echo "$token_response" | grep -oP '"token"\s*:\s*"\K[^"]+')

if [[ -z "$sonar_token" ]]; then
  echo "❌ No se pudo extraer el token de Sonar. Respuesta:"
  echo "$token_response"
  echo "Continuando con el token predeterminado en la configuración..."
else
  echo "✅ Token de SonarQube generado: $sonar_token"

  # Configurar URL base de SonarQube
  echo "🌐 Configurando URL base de SonarQube..."
  curl -s -u "admin:MiPasswordSegura123!" \
    -X POST "http://$ci_vm_ip:9000/api/settings/set" \
    -d "key=sonar.core.serverBaseURL" \
    -d "value=http://$ci_vm_ip:9000/"

  # Actualizar token de SonarQube en el archivo de host_vars
  echo "📝 Actualizando sonar_token en inventory/host_vars/jenkins.yml..."
  sed -i "s/sonar_token:.*/sonar_token: \"$sonar_token\"/" inventory/host_vars/jenkins.yml

  # Crear webhook en SonarQube para Jenkins
  echo "🔄 Registrando webhook de SonarQube a Jenkins..."
  curl -s -u "admin:MiPasswordSegura123!" \
    -X POST "http://$ci_vm_ip:9000/api/webhooks/create" \
    -d "name=Jenkins" \
    -d "url=http://$ci_vm_ip:80/sonarqube-webhook/"
fi

# Implementar Jenkins
echo "🛠️ Desplegando Jenkins..."
ansible-playbook -i inventory/hosts.ini playbooks/deploy_jenkins.yml

echo "🎉 Implementación completada con éxito."
echo "📋 Accesos:"
echo "  - Jenkins: http://$ci_vm_ip"
echo "  - SonarQube: http://$ci_vm_ip:9000"
echo "  - Microservicios: Revisar la IP en inventory/secrets.yml (microservices_vm_ip)"

echo "🏁 Todos los playbooks ejecutados correctamente."