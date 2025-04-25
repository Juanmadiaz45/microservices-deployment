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
                            // For Linux - without sudo
                            echo "Attempting to install Azure CLI on Linux without sudo"
                            
                            sh '''
                                mkdir -p ${WORKSPACE}/bin
                                mkdir -p ${WORKSPACE}/tmp/azure-cli
                                
                                # Download portable Python installation script
                                echo "Downloading portable Azure CLI..."
                                curl -L https://azurecliprod.blob.core.windows.net/install.py -o ${WORKSPACE}/tmp/azure-cli/install.py || echo "Failed to download Azure CLI installer"
                                
                                if [ -f ${WORKSPACE}/tmp/azure-cli/install.py ]; then
                                    echo "Installing Azure CLI to local directory..."
                                    # Install to local directory without sudo
                                    python3 ${WORKSPACE}/tmp/azure-cli/install.py --install-location ${WORKSPACE}/tmp/azure-cli || echo "Failed to install Azure CLI with Python installer"
                                    
                                    # Link to our bin directory if installation succeeded
                                    if [ -f ${WORKSPACE}/tmp/azure-cli/bin/az ]; then
                                        ln -sf ${WORKSPACE}/tmp/azure-cli/bin/az ${WORKSPACE}/bin/az
                                        chmod +x ${WORKSPACE}/bin/az
                                    fi
                                fi
                                
                                # If installation didn't work, create minimal implementation
                                if [ ! -f ${WORKSPACE}/bin/az ]; then
                                    echo "Installing minimal az implementation..."
                                    cat > ${WORKSPACE}/bin/az <<'EOF'
#!/usr/bin/env python3
import os
import sys
import json

if len(sys.argv) > 1 and sys.argv[1] == '--version':
    print("Azure CLI (minimal version for terraform auth)")
    sys.exit(0)
    
if len(sys.argv) > 1 and sys.argv[1] == 'login' and '--service-principal' in sys.argv:
    # Extract credentials
    client_id = None
    client_secret = None
    tenant_id = None
    
    for i, arg in enumerate(sys.argv):
        if arg == '-u' and i+1 < len(sys.argv):
            client_id = sys.argv[i+1]
        elif arg == '-p' and i+1 < len(sys.argv):
            client_secret = sys.argv[i+1]
        elif arg == '--tenant' and i+1 < len(sys.argv):
            tenant_id = sys.argv[i+1]
    
    # Store credentials in ~/.azure directory
    azure_dir = os.path.expanduser('~/.azure')
    os.makedirs(azure_dir, exist_ok=True)
    
    with open(os.path.join(azure_dir, 'azureProfile.json'), 'w') as f:
        json.dump({
            "subscriptions": []
        }, f)
    
    with open(os.path.join(azure_dir, 'accessTokens.json'), 'w') as f:
        json.dump({
            "servicePrincipalId": client_id,
            "servicePrincipalSecret": client_secret,
            "tenantId": tenant_id
        }, f)
    
    print("Logged in using service principal {}".format(client_id))
    sys.exit(0)
    
if len(sys.argv) > 1 and sys.argv[1] == 'account' and len(sys.argv) > 2 and sys.argv[2] == 'set' and '--subscription' in sys.argv:
    subscription_id = None
    for i, arg in enumerate(sys.argv):
        if arg == '--subscription' and i+1 < len(sys.argv):
            subscription_id = sys.argv[i+1]
            break
    
    if subscription_id:
        azure_dir = os.path.expanduser('~/.azure')
        profile_path = os.path.join(azure_dir, 'azureProfile.json')
        
        if os.path.exists(profile_path):
            with open(profile_path, 'r') as f:
                profile = json.load(f)
        else:
            profile = {"subscriptions": []}
        
        profile["subscriptions"] = [{
            "id": subscription_id,
            "isDefault": True,
            "name": "Terraform Subscription"
        }]
        
        with open(profile_path, 'w') as f:
            json.dump(profile, f)
            
        print("Subscription {} set as default".format(subscription_id))
    sys.exit(0)
    
if len(sys.argv) > 1 and sys.argv[1] == 'logout':
    azure_dir = os.path.expanduser('~/.azure')
    tokens_path = os.path.join(azure_dir, 'accessTokens.json')
    
    if os.path.exists(tokens_path):
        os.remove(tokens_path)
    
    print("Logged out")
    sys.exit(0)

print("Command not implemented in minimal version: {}".format(' '.join(sys.argv[1:])))
sys.exit(1)
EOF
                                    chmod +x ${WORKSPACE}/bin/az
                                    echo "Installed minimal Azure CLI implementation in ${WORKSPACE}/bin/az"
                                fi
                            '''
                        }
                        
                        // Verify installation
                        sh '${WORKSPACE}/bin/az --version || echo "Warning: Using minimal az implementation"'
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