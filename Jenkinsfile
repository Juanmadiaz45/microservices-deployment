pipeline {
    agent any
    
    environment {
        TERRAFORM_DIR = "${WORKSPACE}/terraform"
        TERRAFORM_VERSION = "1.7.5" // You can adjust this version as needed
        PATH = "${WORKSPACE}/bin:${env.PATH}"
        AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
        AZURE_ADMIN_USERNAME = credentials('AZURE_ADMIN_USERNAME')
        AZURE_ADMIN_PASSWORD = credentials('AZURE_VM_PASSWORD')
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
                            // Clean up any previous temporary files
                            sh 'rm -rf tmp || true'
                            // Create temp directory for download
                            sh 'mkdir -p tmp'
                            // Download Terraform
                            sh "curl -o tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_windows_amd64.zip"
                            // Unzip and make available in PATH (with overwrite flag)
                            sh 'unzip -o tmp/terraform.zip -d tmp'
                            sh 'mv tmp/terraform.exe ${WORKSPACE}/bin/'
                            sh 'rm -rf tmp'
                        } else {
                            // Clean up any previous temporary files
                            sh 'rm -rf tmp || true'
                            // For Linux
                            sh 'mkdir -p tmp'
                            sh "curl -o tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                            sh 'unzip -o tmp/terraform.zip -d tmp'
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
        
        stage('Install Azure CLI') {
            steps {
                script {
                    // Check if Azure CLI is already installed
                    def azCliInstalled = sh(script: '${WORKSPACE}/bin/az --version || echo "NOT_INSTALLED"', returnStdout: true)
                    
                    if (azCliInstalled.contains("NOT_INSTALLED")) {
                        echo "Installing Azure CLI"
                        
                        // For Windows
                        if (isUnix() == false) {
                            // Download and install Azure CLI
                            sh 'mkdir -p tmp'
                            sh 'curl -o tmp/azure-cli-installer.msi https://aka.ms/installazurecliwindows'
                            sh 'msiexec /i tmp/azure-cli-installer.msi /quiet'
                            sh 'rm -rf tmp'
                            
                            // Add to PATH
                            sh 'setx PATH "%PATH%;C:\\Program Files (x86)\\Microsoft SDKs\\Azure\\CLI2\\wbin"'
                            
                            // Create a symlink to access az from workspace bin
                            sh 'mklink ${WORKSPACE}\\bin\\az.exe "C:\\Program Files (x86)\\Microsoft SDKs\\Azure\\CLI2\\wbin\\az.exe" || echo "Symlink already exists or could not be created"'
                        } else {
                            // For Linux
                            sh '''
                                curl -sL https://aka.ms/InstallAzureCLIDeb | bash
                                ln -sf /usr/bin/az ${WORKSPACE}/bin/az
                            '''
                        }
                        
                        // Verify installation
                        sh '${WORKSPACE}/bin/az --version'
                    } else {
                        echo "Azure CLI is already installed: ${azCliInstalled}"
                    }
                }
            }
        }
        
        stage('Azure Login') {
            steps {
                withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                    sh '''
                        ${WORKSPACE}/bin/az login --service-principal \
                        -u $AZURE_CLIENT_ID \
                        -p $AZURE_CLIENT_SECRET \
                        --tenant $AZURE_TENANT_ID
                        
                        ${WORKSPACE}/bin/az account set --subscription $AZURE_SUBSCRIPTION_ID
                    '''
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
                sh '''
                    ${WORKSPACE}/bin/terraform plan \
                    -var="subscription_id=${AZURE_SUBSCRIPTION_ID}" \
                    -var="admin_username=${AZURE_CLIENT_ID}" \
                    -var="admin_password=${AZURE_ADMIN_PASSWORD}" \
                    -out=tfplan
                '''
            }
            }
        }
        
        stage('Approval') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir(env.TERRAFORM_DIR) {
                    sh '${WORKSPACE}/bin/terraform apply -auto-approve tfplan'
                }
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
        always {
            sh '${WORKSPACE}/bin/az logout || echo "Already logged out"'
        }
    }
}