pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')      
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')  
        AWS_DEFAULT_REGION = 'us-east-1'        
    }  

    stages {
        stage('Build AMI') {
            steps {
                dir('PACKER/packer') {
                    sh '''
                        packer init ami.pkr.hcl
                        packer validate ami.pkr.hcl
                        packer build ami.pkr.hcl
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'AMI build completed successfully!'                   
        }
        failure {
            echo 'AMI build failed. Check logs above.'
        }
    }
}