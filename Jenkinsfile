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
                sh """
                    packer init packer/ami.pkr.hcl
                    packer validate packer/ami.pkr.hcl
                    packer build \
                        -var 'build_number=${BUILD_NUMBER}' \
                        packer/ami.pkr.hcl
                """
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
