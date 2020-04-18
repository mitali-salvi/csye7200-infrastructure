#Set all the variables in this section
CLUSTER_NAME=$1
CLOUD_PROVIDER=aws
IMAGE=k8s.gcr.io/cluster-autoscaler:v1.2.2
MIN_NODES=2
MAX_NODES=3
AWS_REGION=us-east-1
INSTANCE_GROUP_NAME="nodes"
ASG_NAME="${INSTANCE_GROUP_NAME}.${CLUSTER_NAME}"   #ASG_NAME should be the name of ASG as seen on AWS console.
IAM_ROLE="masters.${CLUSTER_NAME}"                  #Where will the cluster-autoscaler process run? Currently on the master node.
SSL_CERT_PATH="/etc/ssl/certs/ca-certificates.crt"  #(/etc/ssl/certs for gce, /etc/ssl/certs/ca-bundle.crt for RHEL7.X)
KOPS_STATE_STORE=$2        #KOPS_STATE_STORE might already be set as an environment variable, in which case it doesn't have to be changed.

echo "Set up Autoscaling"
echo "   First, we need to update the minSize and maxSize attributes for the kops instancegroup."
echo "   The next command will open the instancegroup config in your default editor, please save and exit the file once you're done…"
sleep 1
AWS_PROFILE=$3 kops replace -f roles/cluster-autoscaling/tasks/nodes-instance-group.yaml --state ${KOPS_STATE_STORE} --name ${CLUSTER_NAME}
echo "   Running kops update cluster --yes"
AWS_PROFILE=$3 kops update cluster --yes --state ${KOPS_STATE_STORE} --name ${CLUSTER_NAME}
printf "\n"

printf "   a) Creating IAM policy to allow aws-cluster-autoscaler access to AWS autoscaling groups…\n"
cat > asg-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*"
        }
    ]
}
EOF

ASG_POLICY_NAME=aws-cluster-autoscaler
unset TESTOUTPUT
TESTOUTPUT=$(aws iam list-policies --profile $3 --output json | jq -r '.Policies[] | select(.PolicyName == "aws-cluster-autoscaler") | .Arn')
if [[ $? -eq 0 && -n "$TESTOUTPUT" ]]
then
  printf "Policy already exists\n"
  ASG_POLICY_ARN=$TESTOUTPUT
else
  printf "Policy does not yet exist, creating now.\n"
  ASG_POLICY=$(aws iam create-policy --profile $3 --policy-name $ASG_POLICY_NAME --policy-document file://asg-policy.json --output json)
  ASG_POLICY_ARN=$(echo $ASG_POLICY | jq -r '.Policy.Arn')
  printf "Done creating policy \n"
fi

addon=roles/cluster-autoscaling/tasks/cluster-autoscaler.yml

printf "   b) Attaching policy to IAM Role…\n"
aws iam attach-role-policy --profile $3 --policy-arn $ASG_POLICY_ARN --role-name $IAM_ROLE
printf "Done attaching policy to IAM Role \n"

sed -i -e "s@{{CLOUD_PROVIDER}}@${CLOUD_PROVIDER}@g" "${addon}"
sed -i -e "s@{{IMAGE}}@${IMAGE}@g" "${addon}"
sed -i -e "s@{{MIN_NODES}}@${MIN_NODES}@g" "${addon}"
sed -i -e "s@{{MAX_NODES}}@${MAX_NODES}@g" "${addon}"
sed -i -e "s@{{GROUP_NAME}}@${ASG_NAME}@g" "${addon}"
sed -i -e "s@{{AWS_REGION}}@${AWS_REGION}@g" "${addon}"
sed -i -e "s@{{SSL_CERT_PATH}}@${SSL_CERT_PATH}@g" "${addon}"

kubectl apply -f ${addon}

printf "Done\n"