# Automated Custom AMI Creation with Packer and Jenkins

## Table of Contents
1.  **Prerequisites**
2.  **Project Structure**
3.  **Step 1: Prepare the Ansible Playbook**
4.  **Step 2: Prepare the Packer Template**
5.  **Step 3: Prepare Packer Variables**
6.  **Step 4: Set Up the Jenkins Pipeline**
7.  **Step 5: Run the Jenkins Job**

---

## 1. Prerequisites

Before starting, ensure you have the following:

- **AWS Account** with appropriate permissions (EC2, IAM, S3).
- **Jenkins Server** with:
    - Packer installed (version >= 1.8.0).
    - Ansible installed.
    - AWS CLI configured (or IAM instance role attached).
- **Git Repository** to store Packer and Ansible code.
- **AWS Credentials** configured in Jenkins (`aws-credentials-id`).

---

## 2. Project Structure

Create the following directory structure in your Git repository:

```
packer-jenkins-ami/
├── ansible/
│   └── playbook-ami.yml
├── packer/
│   ├── ami.pkr.hcl
│   └── variables.auto.pkrvars.hcl
└── Jenkinsfile
```

---

## 3. Step 1: Prepare the Ansible Playbook

**File:** `ansible/playbook-ami.yml`

This playbook configures the EC2 instance during the AMI baking process.

```yaml
---
- name: Install packages on Ubuntu AMI
  hosts: all
  become: yes

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Fix broken dependencies
      command: apt-get --fix-broken install -y

    - name: Install basic packages
      apt:
        name: "{{ item }}"
        state: present
      loop:
        - curl
        - wget
        - unzip
        - net-tools

    - name: Install jq
      shell: sudo apt-get install -y jq
      args:
        warn: no

    - name: Install MySQL client
      apt:
        name: mysql-client
        state: present
      ignore_errors: yes

    - name: Install OpenJDK 17 JDK
      apt:
        name: openjdk-17-jdk
        state: present
      register: java_install

    - name: Verify Java installation
      command: java -version
      register: java_version
      changed_when: false

    - name: Display Java version
      debug:
        msg: "{{ java_version.stderr }}"

    - name: Install AWS CLI v2
      shell: |
        cd /tmp
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
      args:
        creates: /usr/local/bin/aws
```

---

## 4. Step 2: Prepare the Packer Template

**File:** `packer/ami.pkr.hcl`

This defines the source AMI, instance type, and uses Ansible as a provisioner.

```hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "service_name" {
  type    = string
}

variable "service_version" {
  type    = string
}

variable "source_ami" {
  type    = string
}

variable "aws_region" {
  type    = string
}

source "amazon-ebs" "ami" {
  ami_name      = "${var.service_name}-${var.service_version}"
  instance_type = "t3.micro"
  region        = var.aws_region
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"
  ssh_timeout   = "10m"
}

build {
  sources = ["source.amazon-ebs.ami"]

  provisioner "ansible" {
    playbook_file = "./ansible/playbook-ami.yml"
    user          = "ubuntu"
    extra_arguments = [
      "--verbose",
      "--ssh-extra-args=-o StrictHostKeyChecking=no"
    ]
  }
}
```

---

## 5. Step 3: Prepare Packer Variables

**File:** `packer/variables.auto.pkrvars.hcl`

This file provides default variable values.

```hcl
service_name     = "my-custom-ami"
service_version  = "1.0.0"
source_ami       = "ami-0c7217cdde317cfec"   # Ubuntu 22.04 LTS in us-east-1
aws_region       = "us-east-1"
```

> **Note:** Verify that `ami-0c7217cdde317cfec` is a valid Ubuntu 22.04 AMI ID for `us-east-1` at the time of execution. Update if necessary.

---

## 6. Step 4: Set Up the Jenkins Pipeline

**File:** `Jenkinsfile` (Declarative Pipeline)

This pipeline checks out code, validates Packer, builds the AMI, and optionally cleans up.

```groovy
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
```

### Jenkins Configuration Steps:

1.  **Create a new Pipeline job** in Jenkins.
2.  **Under "Pipeline" section**, select "Pipeline script from SCM".
3.  **Provide your Git repository URL**.
4.  **Set Script Path** to `Jenkinsfile`.
5.  **Add AWS Credentials** (if not using IAM role):
    - Manage Jenkins → Manage Credentials → Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
    - Update the pipeline to use `withAWS(credentials: 'aws-cred-id') { ... }` around the build step.

---

## 7. Step 5: Run the Jenkins Job

1.  Click **"Build with Parameters"** on your Jenkins job.
2.  Choose `ACTION`:
    - `VALIDATE` → Only checks Packer template syntax.
    - `BUILD` → Creates the actual AMI.
3.  Optionally override `AMI_VERSION` (e.g., `1.0.1`).
4.  Click **Build**.

### Expected Output (Build Stage):

```
==> amazon-ebs.ami: Launching a source AWS instance...
==> amazon-ebs.ami: Provisioning with Ansible...
    playbook-ami.yml: ok=10 changed=5 failed=0
==> amazon-ebs.ami: Stopping the source instance...
==> amazon-ebs.ami: Creating the AMI: my-custom-ami-1.0.0
==> amazon-ebs.ami: AMI: ami-0a1b2c3d4e5f67890
Build 'amazon-ebs.ami' finished successfully.
```
