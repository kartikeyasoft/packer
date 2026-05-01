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
                sh '''
                    # Run from repository root (where both packer/ and ansible/ directories exist)
                    packer init packer/ami.pkr.hcl
                    packer validate packer/ami.pkr.hcl
                    packer build packer/ami.pkr.hcl
                '''
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
