pipeline {
    agent any
    
    environment {
        TERRAFORM_DIR = "${WORKSPACE}/terraform"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Detect Terraform Changes') {
            steps {
                script {
                    def changes = sh(
                        script: "git diff --name-only HEAD^ HEAD | grep -E '^terraform/.*\\.tf\\$' || echo ''",
                        returnStdout: true
                    ).trim()
                    
                    env.TERRAFORM_CHANGES = changes.isEmpty() ? 'false' : 'true'
                    
                    if (env.TERRAFORM_CHANGES == 'true') {
                        echo "Detectados cambios en archivos Terraform: ${changes}"
                    } else {
                        echo "No se detectaron cambios en archivos Terraform"
                    }
                }
            }
        }
        
        stage('Terraform Init') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir(env.TERRAFORM_DIR) {
                    sh 'terraform init'
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir(env.TERRAFORM_DIR) {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }
        
        stage('Approval') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                input message: '¿Continuar con la aplicación de Terraform?', ok: 'Aplicar'
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir(env.TERRAFORM_DIR) {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
        
        stage('Run Ansible') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir("${WORKSPACE}/ansible") {
                    sh 'ansible-playbook -i inventory playbook.yml'
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline ejecutado correctamente'
        }
        failure {
            echo 'Pipeline falló'
        }
    }
}