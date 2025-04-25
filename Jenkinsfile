pipeline {
    agent any
    
    environment {
        TERRAFORM_DIR = "${WORKSPACE}/terraform"
        TERRAFORM_VERSION = "1.7.5" // You can adjust this version as needed
        AZURE_CLI_VERSION = "2.65.0" // Versión actual de Azure CLI
        PATH = "${WORKSPACE}/bin:${env.PATH}"
        AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
        AZURE_ADMIN_USERNAME = credentials('AZURE_ADMIN_USERNAME')
        AZURE_ADMIN_PASSWORD = credentials('AZURE_VM_PASSWORD')
        // Agregamos la variable para autenticación con Service Principal
        AZURE_CLIENT_ID = credentials('AZURE_CLIENT_ID')
        AZURE_CLIENT_SECRET = credentials('AZURE_CLIENT_SECRET')
        AZURE_TENANT_ID = credentials('AZURE_TENANT_ID')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Build Tools') {
            steps {
            sh '''
            apt-get update && apt-get install -y build-essential
            '''
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
                    // Create a bin directory in the workspace if it doesn't exist
                    sh 'mkdir -p ${WORKSPACE}/bin'
                    
                    // Check if Azure CLI is already installed
                    def azCliInstalled = sh(script: '${WORKSPACE}/bin/az --version || echo "NOT_INSTALLED"', returnStdout: true)
                    
                    if (azCliInstalled.contains("NOT_INSTALLED")) {
                        echo "Installing Azure CLI"
                        
                        if (isUnix() == false) {
                            // Windows - Install portable Python and then Azure CLI via pip
                            sh 'mkdir -p ${WORKSPACE}/python'
                            sh 'curl -L https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip -o ${WORKSPACE}/python.zip'
                            sh 'unzip -o ${WORKSPACE}/python.zip -d ${WORKSPACE}/python'
                            sh 'curl -L https://bootstrap.pypa.io/get-pip.py -o ${WORKSPACE}/get-pip.py'
                            sh '${WORKSPACE}/python/python.exe ${WORKSPACE}/get-pip.py'
                            sh '${WORKSPACE}/python/python.exe -m pip install azure-cli==${AZURE_CLI_VERSION}'
                            
                            // Create a batch file wrapper for az
                            sh '''
                            echo @echo off > ${WORKSPACE}/bin/az.bat
                            echo ${WORKSPACE}/python/python.exe -m azure.cli %%* >> ${WORKSPACE}/bin/az.bat
                            '''
                            
                            // Create a shell wrapper for az
                            sh '''
                            echo #!/bin/sh > ${WORKSPACE}/bin/az
                            echo ${WORKSPACE}/python/python.exe -m azure.cli "$@" >> ${WORKSPACE}/bin/az
                            chmod +x ${WORKSPACE}/bin/az
                            '''
                        } else {
                            // Linux - Install portable Python and then Azure CLI via pip
                            sh 'mkdir -p ${WORKSPACE}/python'
                            sh 'curl -L https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz -o ${WORKSPACE}/python.tgz'
                            sh 'mkdir -p ${WORKSPACE}/python_src'
                            sh 'tar -xzf ${WORKSPACE}/python.tgz -C ${WORKSPACE}/python_src'
                            sh 'cd ${WORKSPACE}/python_src/Python-3.10.11 && ./configure --prefix=${WORKSPACE}/python --enable-optimizations && make && make install'
                            sh '${WORKSPACE}/python/bin/pip3 install azure-cli==${AZURE_CLI_VERSION}'
                            
                            // Create a shell wrapper for az
                            sh '''
                            echo '#!/bin/sh' > ${WORKSPACE}/bin/az
                            echo '${WORKSPACE}/python/bin/python -m azure.cli "$@"' >> ${WORKSPACE}/bin/az
                            chmod +x ${WORKSPACE}/bin/az
                            '''
                        }
                        
                        // Verify installation
                        sh '${WORKSPACE}/bin/az --version'
                    } else {
                        echo "Azure CLI is already installed: ${azCliInstalled}"
                    }
                    
                    // Configure Azure CLI to authenticate with Service Principal
                    sh '''
                    ${WORKSPACE}/bin/az login --service-principal \
                    -u ${AZURE_CLIENT_ID} \
                    -p ${AZURE_CLIENT_SECRET} \
                    --tenant ${AZURE_TENANT_ID}
                    '''
                    
                    // Set the subscription
                    sh '${WORKSPACE}/bin/az account set --subscription ${AZURE_SUBSCRIPTION_ID}'
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
        
        stage('Terraform Init and Import') {
            when {
                expression { return env.TERRAFORM_CHANGES == 'true' }
            }
            steps {
                dir(env.TERRAFORM_DIR) {
                    script {
                        // Inicializar Terraform
                        sh '${WORKSPACE}/bin/terraform init'

                        // Verificar si el recurso ya está en el estado
                        def resourceExists = sh(
                            script: '${WORKSPACE}/bin/terraform state list azurerm_resource_group.microservicesrg || echo "NOT_IMPORTED"',
                            returnStdout: true
                        ).trim()

                        if (resourceExists == "NOT_IMPORTED") {
                            echo "Importando el grupo de recursos existente al estado de Terraform..."
                            sh '''
                                ${WORKSPACE}/bin/terraform import \
                                -var="subscription_id=${AZURE_SUBSCRIPTION_ID}" \
                                -var="client_id=${AZURE_CLIENT_ID}" \
                                -var="client_secret=${AZURE_CLIENT_SECRET}" \
                                -var="tenant_id=${AZURE_TENANT_ID}" \
                                -var="admin_password=${AZURE_ADMIN_PASSWORD}" \
                                azurerm_resource_group.microservicesrg \
                                /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/microservicesrg
                            '''
                        } else {
                            echo "El grupo de recursos ya está gestionado por Terraform."
                        }
                    }
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
                        -var="client_id=${AZURE_CLIENT_ID}" \
                        -var="client_secret=${AZURE_CLIENT_SECRET}" \
                        -var="tenant_id=${AZURE_TENANT_ID}" \
                        -var="admin_username=${AZURE_ADMIN_USERNAME}" \
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
    }
}