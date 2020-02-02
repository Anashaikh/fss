# terraform-aws-k8s-pipeline for installing Flight Schedule Service for Quantum Airlines
This stack will provide a CI/CD infrastructure on AWS using Terraform and Kubernetes (using kops).
Helm will install External-dns, Jenkins, (kubectl) Flight Schedule Service pod, mysql, grafana and prometheus 
server

---
###### *Navigate* | [*Top*](#terraform-aws-k8s-pipeline) | [*1) Requisites and Configurations*](#1-requisites-and-Configurations-before-start) | [*2) Infrastructure Creation*](#2-infrastructure-creation)  [*3) Infrastructure exclusion*](#3-infrastructure-exclusion) 
---

## 1) Requisites and Configurations before start
  

### 1.1) Tools
- Terraform - `v0.11.13` - [MacOS](https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_darwin_amd64.zip) / [Linux](https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip)
- Kops - `v1.11.1` - [MacOS](https://github.com/kubernetes/kops/releases/download/1.11.1/kops-darwin-amd64) / [Linux](https://github.com/kubernetes/kops/releases/download/1.11.1/kops-linux-amd64)
- Kubectl - `v1.11.10` - [MacOS](https://storage.googleapis.com/kubernetes-release/release/v1.11.10/bin/darwin/amd64/kubectl) / [Linux](https://storage.googleapis.com/kubernetes-release/release/v1.11.10/bin/linux/amd64/kubectl)
- Helm - `2.14.1`- [MacOS](https://get.helm.sh/helm-v2.14.1-darwin-amd64.tar.gz) / [Linux](https://get.helm.sh/helm-v2.14.1-linux-amd64.tar.gz)
- Python - `2.7.10` and `3.7.2`
- Python Libs - (Boto, Boto3 and BotoCore for Python 2.x and 3.x)
- aws-cli - `aws-cli/1.16.110 Python/3.7.2 Darwin/18.6.0 botocore/1.12.100`
- jq - `1.6` - Command-line JSON processor

### 1.2) Configuration
- Terraform: [terraform/configuration.tf](terraform/configuration.tf)
  - In this file, you can configure a lot of items related to your project. I'd like to highlight some items that you definitely have to customize for your case:
    - `${locals.application}`
    - `${locals.route53_host_zone}`
    - `${locals.k8s_cluster_name}`
- AWS
  - `aws-cli` with a configured profile: Following the best practices and to be compatible with this project, you should configure your AWS Command Line to use profiles.
    - After installing the `aws-cli`, run in your console:
      - ```shell
            $ aws configure --profile <PROFILE_NAME>

            AWS Access Key ID [None]: <ACCESS_KEY_ID>
            AWS Secret Access Key [None]: <SECRET_KEY>
            Default region name [None]: <DEFAULT_REGION>
            Default output format [None]: <OUTPUT>
        ```
      - I'm using `us-east-1` for this project as `DEFAULT_REGION` (check `${locals.vpc_azs}`)
  - To be able to work in a colaborative way, I'm saving the Terraform status in a `S3 bucket` and controlling concurrent tasks with a `DynamoDB table`. You can check and modify these configurations in the `${terraform.backend}` group at [terraform/configuration.tf](terraform/configuration.tf).
    - Anyway, you will need to create these referenced resources manually:
      - Create an S3 Bucket (optionally you can enable the versioning on this buckets, like a git =)
        - BucketName: `ashdev-state-prod`
        - Region: `us-east-1`
      - Create a DynamoDB for lock management
        - TableName: `ashdev-lock-prod`
        - PrimaryKey: `LockID`
        - Region: `us-east-1`
  - Create a Route53 Zone (`ashdev.net` on this case) and configure the Name Servers on your register.
    - We will need a valid FQDN register for Kops. 
    - On this project, I'm using the AWS DNS service Route53. You can use any other service, but you will need to do some adjustments on the Kubernetes DNS management system (External-DNS)
- Ensure that are able to run all the binaries. If not, try to put each one inside the `/usr/local/bin` folder and give the permissions for execution. (terraform, kops, kubectl and helm)
- Ensure that all `.sh` files in the root folder have permission for execution
  - `$ chmod +x *.sh`

Wow, that's it. Let's have fun!

---
###### *Navigate* | [*Top*](#terraform-aws-k8s-pipeline) | [*1) Requisites and Configurations*](#1-requisites-and-Configurations-before-start) | [*2) Infrastructure Creation*](#2-infrastructure-creation)  [*3) Infrastructure exclusion*](#3-infrastructure-exclusion) 
---

## 2) Infrastructure creation

After making your customizations and create the resources mentioned on the [Requisites and Configurations](#1-requisites-and-Configurations-before-start) topic, run each file following the order that I'll guide you.  

Running all scripts, the result will be the creating of  VPC, Subnets, NAT Gateways, AutoScaling Groups, Load Balancer, Route53, DynamoDB, S3, Kubernetes Master and Nodes and the Pipeline flow with Github, Jenkins and DockerHub ( the pipelines needs a little more testing).  


---

The files are separated by prefix groups to be easy to create more scripts and to define its priority.  


### 2.1) File [001.aws-infra.sh](001.aws-infra.sh)

```shell
$ AWS_PROFILE=<profile_name> ./001.aws-infra.sh
```

This shell script will access the Terraform config files and will provide a basic infrastructure to create the Kubernetes environment. After running this script you will have in your AWS account the following resources:
- VPC
- Subnets Public and Private
- Internet Gateways
- NAT Gateways for providing internet access to the internal instances
- Route Tables
- Security group with inbound traffic to accept external access on K8s Ingress Load Balancer
- S3 Bucket for save Kops state
- Also, you will have some outputs mapped for further use in the next steps

After you run this script, you should be able to see the Terraform output about each resource that was created:  


---

### 2.2) File [002.k8s-install.sh](002.k8s-install.sh)

```shell
$ AWS_PROFILE=<profile_name> ./002.k8s-install.sh
```

This shell script will access the Kubernetes folder and generate a cluster template with [kops](https://github.com/kubernetes/kops) based on the outputs of our last step.  
After that, I will use this template together with Terraform to provide the Kubernetes cluster.

After run this script I will generate some resources for you:
- Route53 entries for cluster management
- IAM Roles for master and node instances
- Security groups
- Master and Node instances in an isolated way using private subnets
- Etcd EBS volumes
- An ELB for Kubernetes API
- AutoScaling groups for Master and Node in case of failure

I also will configure your `kubectl` and you will be ready to run commands in your cluster:  


---

### 2.3) File [003.kops-validate-cluster.sh](003.kops-validate-cluster.sh)

```shell
$ AWS_PROFILE=<profile_name> ./003.kops-validate-cluster.sh
```

This step is very important to check if everything is ok.  
You should run the script and get a message confirming that your cluster is up and running.  

`Only continue to the other steps after passing this step.`  

While your cluster is being created or the DNS is propagating this script could fail.  
Don't worry with that, wait a little bit and try again.  

---

### 2.4) File [100.helm-config.sh](100.helm-config.sh)

```shell
$ AWS_PROFILE=<profile_name> ./100.helm-config.sh
```

Now that everything is already running properly we will initialize the [Helm](https://helm.sh/) in your cluster to help us in some packages management.  
All that you need to know right now about Helm is that it is like [Maven](https://maven.apache.org/) for Java or [NPM](https://www.npmjs.com/) and [Yarn](https://yarnpkg.com/en/) for NodeJS.  
It's very easy to install, uninstall, upgrade, even the most complex Kubernetes application.
You can get more info about Helm in its [documentation](https://helm.sh/docs/).  


---

### 2.5) File [101.k8s-extras.sh](101.k8s-extras.sh)

```shell
$ AWS_PROFILE=<profile_name> ./101.k8s-extras.sh
```

Now we reach an important point of our infrastructure provisioning.  
This script will install some important pieces of your Kubernetes cluster:
- `External DNS Controller`
- `Mysql Server`
- `Flight Schedule Service Pod - Parasing data into the mysql database`
- `Jenkins`
- `Grafana`
- `Prometheus`
   
I have used Helm to install the flight schedule service pod, this can also be installed via Jenkins CI/CD.
A jenkine pipeline script is provided inside the pipeline directory.
In order to create the Jenkins Pipeline, credentials needs to be created on Jenkins for accessing Kubernetes, Webhooks can be configured through github and then added to the Jenkins Job.
Afterwards a job needs to be created which will deploy the application on the Kubernetes Cluster
---
###### *Navigate* | [*Top*](#terraform-aws-k8s-pipeline) | [*1) Requisites and Configurations*](#1-requisites-and-Configurations-before-start) | [*2) Infrastructure Creation*](#2-infrastructure-creation)  [*3) Infrastructure exclusion*](#3-infrastructure-exclusion) 
---


## 3) Infrastructure exclusion

You can delete all resources that we have created following the scripts below:
- `$ AWS_PROFILE=<profile_name> ./500.remove-k8s.sh`
- `$ AWS_PROFILE=<profile_name> ./501.remove-aws-infra.sh`

---
###### *Navigate* | [*Top*](#terraform-aws-k8s-pipeline) | [*1) Requisites and Configurations*](#1-requisites-and-Configurations-before-start) | [*2) Infrastructure Creation*](#2-infrastructure-creation)  [*3) Infrastructure exclusion*](#3-infrastructure-exclusion) 
---

