pipeline {
    agent {
        docker {
            image 'hashicorp/terraform:1.11.4'
            args '-v /tmp:/tmp'
        }
    }
    
    environment {
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
        
        stage('Terraform Version') {
            steps {
                sh 'terraform --version'
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh 'terraform plan -out=tfplan'
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
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
        
        stage('Deploy Configuration') {
            agent {
                docker {
                    image 'cytopia/ansible:latest'
                    args '-v /tmp:/tmp'
                }
            }
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
    }
}