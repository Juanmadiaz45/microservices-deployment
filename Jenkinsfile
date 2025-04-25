pipeline {
    agent any
    
    environment {
        TERRAFORM_DIR = "${WORKSPACE}/terraform"
        TERRAFORM_VERSION = "1.7.5" // You can adjust this version as needed
        PATH = "${WORKSPACE}/bin:${env.PATH}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install Terraform') {
            steps {
                script {
                    // Create a bin directory in the workspace
                    sh 'mkdir -p ${WORKSPACE}/bin'
                    
                    // Check if Terraform is already installed
                    def terraformInstalled = sh(script: '${WORKSPACE}/bin/terraform --version || echo "NOT_INSTALLED"', returnStdout: true)
                    
                    if (terraformInstalled.contains("NOT_INSTALLED")) {
                        echo "Installing Terraform ${TERRAFORM_VERSION}"
                        
                        // For Windows
                        if (isUnix() == false) {
                            // Create temp directory for download
                            sh 'mkdir -p tmp'
                            // Download Terraform
                            sh "curl -o tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_windows_amd64.zip"
                            // Unzip and make available in PATH
                            sh 'unzip tmp/terraform.zip -d tmp'
                            sh 'mv tmp/terraform.exe ${WORKSPACE}/bin/'
                            sh 'rm -rf tmp'
                        } else {
                            // For Linux
                            sh 'mkdir -p tmp'
                            sh "curl -o tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                            sh 'unzip tmp/terraform.zip -d tmp'
                            sh 'mv tmp/terraform ${WORKSPACE}/bin/'
                            sh 'chmod +x ${WORKSPACE}/bin/terraform'
                            sh 'rm -rf tmp'
                        }
                        
                        // Verify installation
                        sh '${WORKSPACE}/bin/terraform --version'
                    } else {
                        echo "Terraform is already installed: ${terraformInstalled}"
                    }
                }
            }
        }
        
        stage('Detect Terraform Changes') {
            steps {
                script {
                    def changes = sh(
                        script: 'git diff --name-only HEAD^ HEAD | grep -E "^terraform/.*\\.tf$" || echo ""',
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
                    sh '${WORKSPACE}/bin/terraform init'
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir(env.TERRAFORM_DIR) {
                    sh '${WORKSPACE}/bin/terraform plan -out=tfplan'
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
                    sh '${WORKSPACE}/bin/terraform apply -auto-approve tfplan'
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