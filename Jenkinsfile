pipeline {
    agent any
    
    environment {
        TERRAFORM_VERSION = '1.6.6'
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
        
        stage('Install Terraform') {
            steps {
                sh '''
                    if ! command -v wget &> /dev/null; then
                        echo "Installing wget..."
                        apt-get update && apt-get install -y wget unzip
                    fi
                    
                    if ! command -v terraform &> /dev/null; then
                        echo "Terraform not found, installing..."
                        wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        sudo mv terraform /usr/local/bin/
                        rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    else
                        echo "Terraform is already installed"
                    fi
                    terraform --version
                '''
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform init
                    '''
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform validate
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform plan -out=tfplan
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
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }
        
        stage('Deploy Configuration') {
            steps {
                dir('ansible') {
                    sh '''
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