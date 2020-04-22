# CSYE 7220 - Infrastructure
## Team Information
| Name | Email Address |
| --- | --- |
| Mitali Salvi| salvi.mi@husky.neu.edu |
| PinHo Wang| wang.pinh@husky.neu.edu |


## Pre-requisites
You need to configure the following first before using this playbook:
1. Add AWS credentials of member accounts (For KOPS)
2. Clear boto config
3. Create S3 bucket for KOPS State Store
4. Generate new SSH key for connecting to bastion node


### 1. Create IAM users
Create a new IAM user in each member accounts having console as well as programmatic access. Attach followig policies to these users:

1. AdministratorAccess
2. AmazonRoute53DomainsFullAccess

> Note: Make sure you download the Access Keys file (*.csv) for each user. These keys will be used to setup profiles in the next step.

### 2. Setting up AWS profiles of member accounts
Open `~/.aws/credentials` in any text editor. It should look like the following:
```ini
[default]
aws_access_key_id = <aws-access-key-id-of-root-account>
aws_secret_access_key = <aws-secret-access-key-for-root-account>

```

Append credentials of your member accounts, and tag them with profile names. In our case, it is `dev` and `prod`, which represent our different environments.

```ini
[default]
aws_access_key_id = <aws-access-key-id-for-root-account>
aws_secret_access_key = <aws-secret-access-key-for-root-account>

[dev]
aws_access_key_id = <aws-access-key-id-for-dev-account>
aws_secret_access_key = <aws-secret-access-key-for-dev-account>

[prod]
aws_access_key_id = <aws-access-key-id-for-prod-account>
aws_secret_access_key = <aws-secret-access-key-for-prod-account>

```

>Note: In this document, we will refer to `dev` and `prod` as `<environment>` corresponding to the member accounts

### 3. Clear boto config
If we have `~/.aws/credentials`, we do not need `~/.boto`. So open `~/.boto` in any text editor and make sure there is nothing in it.


### 4. Create DNS hosted zones
>Note: It is assumed that you have a DNS Hosted Zone in your root account, from the course CSYE6225 (referred as `<domain-name>`)

For kops/k8s we need to have a domain/hosted zone. Create public and private DNS hosted zones using the AWS Route 53 service for each of your member accounts. Name these Hosted Zones as follows:

`prod.<domain-name>`. 


### 5. Create S3 bucket for KOPS State Store

Create an S3 bucket in `us-east-1` region for each of your member accounts. The name of the bucket can be anything but the following format is recommended:-

`prod.<domain-name>-state-store`


### 6. Generate new SSH key for connecting to bastion host

Create a new SSH key using the following command:

```sh
ssh-keygen -t rsa -C "your_email_id"

```
Note the path of the public key file


## Create/Delete Kubernetes cluster

Run the playbook `main.yaml` in the root of the repository with extra variables (some are required).

```sh
ansible-playbook main.yaml --extra-vars "<variable-key>=<variable-value>"

```


### **Given below is the list of accepted variables.**

| Key | Required | Default | Values |
| --- | --- | --- | --- |
| command | Yes |  | String - start \| delete |
| kops_state_store | Yes |  | String - ARN of the s3 bucket. Eg. s3://s3bucketname |
| cluster_name | Yes |  | String - Name of the cluster created. Eg. cluster.example.com |
| dns_zone_id | Yes (if command=start) |  | String - DNS ZONE ID of the private hosted zone (Can be found in Route 53) |
| fluentd_accessid | Yes |  | String - access id of fluentd IAM user |
| fluentd_accesskey | Yes |  | String - access key of fluentd IAM user |
| public_dns_zone_id | Yes | | String - DNS ZONE ID of the public hosted zone (Can be found in Route 53) |
| public_domain_name | Yes | | String - Name of your domain |
| node_count | No | 3 | Number - Number of worker nodes |
| ssh_path | No |  | String - Path of the public SSH key previously generated |
| master_count | No | 3 | Number - Number of Master Nodes |
| node_size | No | t2.medium | String - Type of EC2 Instance |
| master_size | No | t2.medium | String - Type of EC2 Instance |
| topology | No | private | String - public \| private |
| networking | No | weave | String - Networking mode to use. kubenet \| classic \| external \| kopeio-vxlan (or kopeio) \| weave \| flannel-vxlan (or flannel) \| flannel-udp \| calico \| canal \| kube-router \| romana \| amazon-vpc-routed-eni \| cilium \| cni. |
| bastion | No | true | Boolean - true \| false |
| dns | No | private | String - public \| private |
| cloud | No | aws | String - gce \| aws \| vsphere \| openstack |
| profile | No | dev | String - AWS named profile in `~/.aws/credentials` |
| k8s_version | No | 1.13.0 | String - Kubernetes Version |


### To create a Kubernetes Cluster use the following

Run the following command in the root of the project

```xml
ansible-playbook main.yaml --extra-vars "command=start cluster_name=<name-of-your-cluster> kops_state_store=s3://<name-of-your-s3-bucket> dns_zone_id=<private-hosted-zone-id> ssh_path="ssh_file_path" profile=<aws-profile> fluentd_accessid=<fluentd-iam-user-access-id> fluentd_accesskey=<fluentd-iam-user-access-key> public_dns_zone_id=<public-hosted-zone-id>  public_domain_name=<domain-name>"
```


### To connect to the bastion node, use the ssh key passed in the previous command:- 
```sh
ssh -o "IdentitiesOnly=yes" -i /path/to/key admin@"DNSNameOfLoadBalancer"
```


### To delete a Kubernetes Cluster use the following
Run the following command in the root of the project

```xml
ansible-playbook main.yaml --extra-vars "command=delete cluster_name=<name-of-your-cluster> kops_state_store=s3://<name-of-your-s3-bucket>"
```


### To ssh into bastion node

```sh
ssh -i <YourPrivateKey> ec2-user@<Public Dns Ip>
```
