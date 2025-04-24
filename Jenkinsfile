pipeline {
    agent any
    
    environment {
        TERRAFORM_VERSION = '1.11.4'
        AZURE_SUBSCRIPTION_ID = credentials('AZURE_SUBSCRIPTION_ID')
        AZURE_CLIENT_ID = credentials('AZURE_CLIENT_ID')
        AZURE_CLIENT_SECRET = credentials('AZURE_CLIENT_SECRET')
        AZURE_TENANT_ID = credentials('AZURE_TENANT_ID')
        SSH_CREDENTIALS = credentials('SSH_CREDENTIALS')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh '''
                    apt-get update || true
                    apt-get install -y wget unzip curl || true
                '''
            }
        }
        
        stage('Install Terraform') {
            steps {
                sh '''
                    if ! command -v terraform &> /dev/null; then
                        echo "Terraform not found, installing..."
                        # Try curl if wget is not available
                        if command -v wget &> /dev/null; then
                            wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        elif command -v curl &> /dev/null; then
                            curl -s -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        else
                            echo "Neither wget nor curl is available. Cannot download Terraform."
                            exit 1
                        fi
                        
                        unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        
                        # Try to move to a directory in PATH without sudo
                        mkdir -p $HOME/bin
                        mv terraform $HOME/bin/
                        chmod +x $HOME/bin/terraform
                        export PATH=$HOME/bin:$PATH
                        rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    else
                        echo "Terraform is already installed"
                    fi
                    
                    # Verify terraform is in PATH
                    echo "PATH=$PATH"
                    terraform --version || $HOME/bin/terraform --version
                '''
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh '''
                        export PATH=$HOME/bin:$PATH
                        terraform init || $HOME/bin/terraform init
                    '''
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh '''
                        export PATH=$HOME/bin:$PATH
                        terraform validate || $HOME/bin/terraform validate
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                        export PATH=$HOME/bin:$PATH
                        terraform plan -out=tfplan || $HOME/bin/terraform plan -out=tfplan
                    '''
                }
            }
        }
        
        stage('Approval') {
            steps {
                input message: 'Do you want to apply these infrastructure changes?', ok: 'Apply'
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh '''
                        export PATH=$HOME/bin:$PATH
                        terraform apply -auto-approve tfplan || $HOME/bin/terraform apply -auto-approve tfplan
                    '''
                }
            }
        }
        
        stage('Deploy Configuration') {
            steps {
                dir('ansible') {
                    sh '''
                        chmod +x ./deploy.sh
                        ./deploy.sh
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo 'Infrastructure deployment completed successfully!'
        }
        failure {
            echo 'Infrastructure deployment failed!'
        }
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
}