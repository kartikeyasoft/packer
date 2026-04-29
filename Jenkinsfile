pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        PACKER_LOG = '1'           // Enable Packer logging
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['BUILD', 'VALIDATE'],
            description: 'Select BUILD to create AMI or VALIDATE to check syntax'
        )
        string(
            name: 'AMI_VERSION',
            defaultValue: '1.0.0',
            description: 'Version tag for the AMI (overrides variables.auto.pkrvars.hcl)'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Packer Template') {
            steps {
                dir('packer') {
                    sh '''
                        packer init .
                        packer validate .
                    '''
                }
            }
        }

        stage('Build AMI') {
            when {
                expression { params.ACTION == 'BUILD' }
            }
            steps {
                dir('packer') {
                    sh '''
                        # Override version if provided
                        packer build \
                            -var "service_version=${params.AMI_VERSION}" \
                            .
                    '''
                }
            }
            post {
                success {
                    echo 'AMI build completed successfully!'
                    script {
                        // Optional: Capture AMI ID from Packer output
                        def ami_id = sh(script: "grep -oP 'ami-[a-f0-9]+' packer/manifest.json | tail -1", returnStdout: true).trim()
                        echo "New AMI ID: ${ami_id}"
                    }
                }
                failure {
                    echo 'AMI build failed. Check logs above.'
                }
            }
        }
    }

    post {
        always {
            cleanWs()  // Clean workspace
        }
    }
}