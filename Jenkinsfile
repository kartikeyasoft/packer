pipeline {
    agent any

    environment {
        AWS_CREDENTIALS = credentials('aws-credentials')
        AWS_ACCESS_KEY_ID = "${AWS_CREDENTIALS_USR}"
        AWS_SECRET_ACCESS_KEY = "${AWS_CREDENTIALS_PSW}"
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
