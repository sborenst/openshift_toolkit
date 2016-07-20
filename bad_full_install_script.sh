#!/bin/bash
################################################################################
################################################################################
# This Script will be used to deploy the OSE_FastAdv and OSE_Demo blueprints
# This is a temporary method until we do this properly with Ansible playbooks.
# Steps in the scripts are:
## Step 0 - Define variables for deployment.
## Step 1 - Prepare environment and test that all hosts are up
## Step 2 - Install OpenShift
## Step 3 - Configure OpenShift (Namespaces, router and registry)
## Step 4 - Post-Configure OpenShift (Metrics, Logging)
## Step 5 - Demo content deployment
################################################################################
################################################################################


################################################################################
## Step 0 - Define variables for deployment.
################################################################################
#OPENTLC VARS
export LOGFILE="/root/.oselab.log"
export USER=$1
#export USER="shacharb-redhat.com"
export COURSE=$2;
#export COURSE="ose_demo3.2"

#Common SCRIPT VARS
export DATE=`date`;
export REPOVERSION="3.2"
export SCRIPTVERSION='1.0';
export GUID=`hostname|cut -f2 -d-|cut -f1 -d.`
export guid=`hostname|cut -f2 -d-|cut -f1 -d.`


#ENVIRONMENT VARS, these can be overwritten in the next step, for demos or labs.
export ALLNODES="node1.example.com node2.example.com node3.example.com infranode1.example.com"
export ALLMASTERS="master1.example.com"
export ALLHOSTS="${ALLNODES} ${ALLMASTERS}"
export FIRSTMASTER=`echo $ALLMASTERS | awk '{print $1}'`

echo "---- Starting Log ${DATE}"  2>&1 | tee -a $LOGFILE
echo "---- Step 0 - Define variables for deployment."  2>&1 | tee -a $LOGFILE
echo "---- Logging variables"  2>&1 | tee -a $LOGFILE
echo "-- GUID is $GUID and guid is $guid" 2>&1 | tee -a $LOGFILE
echo "-- Script VERSION ${SCRIPTVERSION}" | tee -a $LOGFILE
echo "-- Hostname is `cat /etc/hostname`"  2>&1 | tee -a $LOGFILE
echo "-- Course name is $COURSE"  2>&1 | tee -a $LOGFILE


# The Demo environment and the Lab environment only differ slightly, we are using
# this simple test to check if the course_id contains the word "demo" and set
# the deployment variables accordingly.

echo "---- Checking if COURSE is demo or lab and setting variables ${DATE}"  2>&1 | tee -a $LOGFILE

echo $COURSE | grep -i demo
if [ $? == '0' ]
  then
    echo "-- This is a demo deployment not a lab deployment" 2>&1 | tee -a $LOGFILE
    echo "-- Setting up Demo variables" 2>&1 | tee -a $LOGFILE

    #CONFIGURATION VARS
    export IDM="TRUE"
    export LOGGING="TRUE"
    export METRICS="TRUE"
    export DEMO="TRUE"
    export DNS="TRUE"
    export NFS="TRUE"

    export USERS="andrew marina karla david"
    export DEVUSER="andrew"
    export ADMINUSER="karla"
    printf "IDM is ${IDM} \nLOGGING is ${LOGGING} \nMETRICS is ${METRICS}\nDEMO is ${DEMO} \nDNS is ${DNS} \nNFS is ${NFS}\n " 2>&1 | tee -a $LOGFILE
  else
    echo "-- This is NOT a DEMO" 2>&1 | tee -a $LOGFILE
    echo "-- Setting up Lab variables" 2>&1 | tee -a $LOGFILE

    #CONFIGURATION VARS
    export IDM="FALSE"
    export LOGGING="FALSE"
    export METRICS="FALSE"
    export DEMO="FALSE"
    export DNS="TRUE"
    export NFS="TRUE"
    export REMOVENODES="node3"

    export USERS="andrew marina karla david"
    export DEVUSER="andrew"
    export ADMINUSER="karla"
    printf "IDM is ${IDM} \nLOGGING is ${LOGGING} \nMETRICS is ${METRICS}\nDEMO is ${DEMO} \nDNS is ${DNS} \nNFS is ${NFS}\n " 2>&1 | tee -a $LOGFILE

fi


################################################################################
## Step 1 - Prepare environemnt and test that all hosts are up
################################################################################
echo "---- Step 1 - Prepare environemnt and test that all hosts are up"  2>&1 | tee -a $LOGFILE

echo "-- Setting StrictHostKeyChecking to no on provisioning host"  2>&1 | tee -a $LOGFILE
echo StrictHostKeyChecking no >> /etc/ssh/ssh_config

echo "-- Updating /etc/motd"  2>&1 | tee -a $LOGFILE

cat << EOF > /etc/motd
###############################################################################
###############################################################################
###############################################################################
Environment Deployment In Progress : ${DATE}
DO NOT USE THIS ENVIRONMENT AT THIS POINT
DISCONNECT AND TRY AGAIN 35 MINUTES FROM THE DATE ABOVE
###############################################################################
###############################################################################
If you want, you can check out the status of the installer by using:
sudo tail -f ${LOGFILE}
###############################################################################

EOF


echo "---- Checking all hosts are up by testing that the docker service is Active"  2>&1 | tee -a $LOGFILE

### Checking all hosts are up
# Test that all the nodes are up, we are testing that the docker service is Active
export ALLCHECKHOSTS=${ALLHOSTS}
export ALLCHECKHOSTSREADY="false";
while [ $ALLCHECKHOSTSREADY == "false" ] ; do
export ALLCHECKHOSTSREADY="true";
for node in ${ALLHOSTS}
 do
   echo "Testing connection for node $node" 2>&1 | tee -a $LOGFILE ;
   ssh $node "systemctl status docker | grep Active"
   if [ $? == 0 ]
    then
      echo "Node $node is ready" 2>&1 | tee -a $LOGFILE ;

    else
      echo "Node $node is not ready" 2>&1 | tee -a $LOGFILE ;
      export ALLCHECKHOSTSREADY="false";
    fi
done
if [ $ALLCHECKHOSTSREADY == "false" ]
  then
  echo "waiting for nodes to start "
  sleep 10;
  fi
done

echo "-- Hosts are up and running the Docker Daemon"  2>&1 | tee -a $LOGFILE



echo "---- Add the Red Hat OpenShift Enterprise $REPOVERSION Repo" 2>&1 | tee -a $LOGFILE
echo "-- Adding OSE3 Repository to  /etc/yum.repos.d/open.repo" 2>&1 | tee -a $LOGFILE
# added the Repo to enable the Ravello Fix packages.
cat << EOF > /etc/yum.repos.d/open.repo
# Created by deployment script
[rhel-7-server-rpms]
name=Red Hat Enterprise Linux 7
baseurl=http://www.opentlc.com/repos/${COURSE}/${REPOVERSION}/rhel-7-server-rpms
enabled=1
gpgcheck=0

[rhel-7-server-rh-common-rpms]
name=Red Hat Enterprise Linux 7 Common
baseurl=http://www.opentlc.com/repos/${COURSE}/${REPOVERSION}/rhel-7-server-rh-common-rpms
enabled=1
gpgcheck=0

[rhel-7-server-extras-rpms]
name=Red Hat Enterprise Linux 7 Extras
baseurl=http://www.opentlc.com/repos/${COURSE}/${REPOVERSION}/rhel-7-server-extras-rpms
enabled=1
gpgcheck=0

[rhel-7-server-optional-rpms]
name=Red Hat Enterprise Linux 7 Optional
baseurl=http://www.opentlc.com/repos/${COURSE}/${REPOVERSION}/rhel-7-server-optional-rpms
enabled=1
gpgcheck=0

[rhel-7-server-ose-3.2-rpms]
name=Red Hat Enterprise Linux 7 OSE $REPOVERSION
baseurl=http://www.opentlc.com/repos/${COURSE}/${REPOVERSION}/rhel-7-server-ose-3.2-rpms
enabled=1
gpgcheck=0


EOF

echo "-- Running yum clean all and yum repolist" 2>&1 | tee -a $LOGFILE

yum clean all 2>&1 | tee -a $LOGFILE
yum repolist 2>&1 | tee -a $LOGFILE

echo "-- Copying /etc/yum.repos.d/open.repo to all nodes"  2>&1 | tee -a $LOGFILE
for node in ${ALLHOSTS}
    do \
    scp /etc/yum.repos.d/open.repo ${node}:/etc/yum.repos.d/open.repo
   ssh ${node} "
      echo "yum clean all and repolist executed on node $node"
      yum clean all ;
      yum repolist
      "&
   done


echo "---- Downloading DNS Installer, NFS Installer and Demo Deployment Script"  2>&1 | tee -a $LOGFILE
mkdir -p /root/.opentlc.installer/
curl -o /root/.opentlc.installer/oselab.dns.installer.sh http://www.opentlc.com/download/${COURSE}/${SCRIPTVERSION}/oselab.dns.installer.sh 2>&1 | tee -a $LOGFILE
curl -o /root/.opentlc.installer/Demo_Deployment_Script.sh http://www.opentlc.com/download/${COURSE}/${SCRIPTVERSION}/Demo_Deployment_Script.sh 2>&1 | tee -a $LOGFILE
curl -o /root/.opentlc.installer/oselab.nfs.installer.sh http://www.opentlc.com/download/${COURSE}/${SCRIPTVERSION}/oselab.nfs.installer.sh 2>&1 | tee -a $LOGFILE
chmod +x /root/.opentlc.installer/oselab.dns.installer.sh /root/.opentlc.installer/Demo_Deployment_Script.sh /root/.opentlc.installer/oselab.nfs.installer.sh

#scp /root/.opentlc.installer/Demo_Deployment_Script.sh root@${FIRSTMASTER}:~  & 2>&1 | tee -a $LOGFILE

if [ $NFS == "TRUE" ]
  then
echo "-- NFS set to ${NFS}, running /root/oselab.nfs.installer.sh"  2>&1 | tee -a ${LOGFILE}
nohup /root/.opentlc.installer/oselab.nfs.installer.sh 2>&1 | tee -a ${LOGFILE}
fi

if [ $DNS == "TRUE" ]
  then
echo "-- DNS set to ${DNS}, running /root/oselab.dns.installer.sh"  2>&1 | tee -a ${LOGFILE}
nohup /root/.opentlc.installer/oselab.dns.installer.sh  2>&1 | tee -a ${LOGFILE}

fi


################################################################################
## Step 2 - Install OpenShift
################################################################################
echo "---- Step 2 - Install OpenShift"  2>&1 | tee -a $LOGFILE


echo "-- install atomic-openshift-utils" 2>&1 | tee -a $LOGFILE
yum -y install atomic-openshift-utils  2>&1 | tee -a $LOGFILE


echo "-- Writing /etc/ansible/hosts file" 2>&1 | tee -a $LOGFILE
cat << EOF > /etc/ansible/hosts
# Create an OSEv3 group that contains the master, nodes, etcd, and lb groups.
# The lb group lets Ansible configure HAProxy as the load balancing solution.
# Comment lb out if your load balancer is pre-configured.
[OSEv3:children]
masters
etcd
nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=root
deployment_type=openshift-enterprise
use_cluster_metrics=true

# Configure metricsPublicURL in the master config for cluster metrics
# See: https://docs.openshift.com/enterprise/latest/install_config/cluster_metrics.html
openshift_master_metrics_public_url=https://metrics.cloudapps-${GUID}.oslab.opentlc.com/hawkular/metrics

# Configure loggingPublicURL in the master config for aggregate logging
# See: https://docs.openshift.com/enterprise/latest/install_config/aggregate_logging.html
openshift_master_logging_public_url=https://kibana.cloudapps-${GUID}.oslab.opentlc.com
# Enable cluster metrics

#openshift_master_identity_providers=[{'name': 'idm', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider', 'attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=example,dc=com', 'bindPassword': 'r3dh4t1!', 'ca': '/etc/origin/master/ipa-ca.crt', 'insecure': 'false', 'url': 'ldap://idm.example.com/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(memberOf=cn=ose-users,cn=groups,cn=accounts,dc=example,dc=com)'}]
#openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/openshift-passwd'}]

osm_default_subdomain=cloudapps-${GUID}.oslab.opentlc.com
#osm_default_node_selector='env=dev'

openshift_hosted_router_selector='region=infra'
openshift_hosted_router_replicas=1
# router's default certificate.
#openshift_hosted_router_certificate={"certfile": "/path/to/router.crt", "keyfile": "/path/to/router.key"}

#### Deploying the registry didn't work for me, manually creating it,
openshift_registry_selector='region=infra'
openshift_registry_replicas=1
# host group for masters
[masters]
master1.example.com

# host group for etcd
[etcd]
master1.example.com

# host group for nodes, includes region info
[nodes]
master1.example.com openshift_public_hostname="master1-${GUID}.oslab.opentlc.com" openshift_hostname="master1.example.com"
infranode1.example.com openshift_hostname="infranode1.example.com" openshift_node_labels="{'region': 'infra', 'zone': 'default', 'env': 'infra'}"
node1.example.com openshift_hostname="node1.example.com" openshift_node_labels="{'region': 'primary', 'zone': 'one', 'env': 'dev'}"
node2.example.com openshift_hostname="node2.example.com" openshift_node_labels="{'region': 'primary', 'zone': 'two', 'env': 'dev'}"
node3.example.com openshift_hostname="node3.example.com" openshift_node_labels="{'region': 'primary', 'zone': 'three', 'env': 'prod'}"
EOF

echo "-- Commenting out nodes according to the REMOVENODES varialbe, value is : ${REMOVENODES} - ok if blank"  2>&1 | tee -a ${LOGFILE}

for node in $REMOVENODES;
  do
    sed -i "/^${node}/s/^/#/" /etc/ansible/hosts
  done

echo "---- IDM set to ${IDM}, Configuring ansible file accordingly"  2>&1 | tee -a ${LOGFILE}

if [ $IDM == "TRUE" ] ; then
    echo "-- IDM is $IDM, Commenting out htpasswd_auth and Uncommenting idm auth"  2>&1 | tee -a $LOGFILE
    sed -i '/htpasswd_auth/s/^/#/' /etc/ansible/hosts
    sed -i '/idm/s/^#//' /etc/ansible/hosts

    echo "-- get ipa-ca.crt file" 2>&1 | tee -a $LOGFILE

    for node in ${ALLMASTERS}
        do \
        ssh ${node} "
        mkdir -p /etc/origin/master/ ;
        wget http://idm.example.com/ipa/config/ca.crt -O /etc/origin/master/ipa-ca.crt;
        cat /etc/origin/master/ipa-ca.crt
        " & 2>&1 | tee -a $LOGFILE
      done

  else
    echo "-- IDM is $IDM, Commenting out idm and Uncommenting htpasswd_auth auth"  2>&1 | tee -a $LOGFILE
    sed -i '/idm/s/^/#/' /etc/ansible/hosts
    sed -i '/htpasswd_auth/s/^#//' /etc/ansible/hosts

    echo "--installing httpd-tools on master " 2>&1 | tee -a $LOGFILE

    for node in ${ALLMASTERS}
        do \
        ssh $node "
    yum -y install httpd-tools
    "  2>&1 | tee -a $LOGFILE &
        done

    yum -y install httpd-tools  2>&1 | tee -a $LOGFILE
    touch /tmp/openshift-passwd
    for user in ${USERS}
        do \
          echo "---- creating users: $USERS" 2>&1 | tee -a $LOGFILE
         echo htpasswd -b /tmp/openshift-passwd $user 'r3dh4t1!'  2>&1 | tee -a $LOGFILE
         htpasswd -b /tmp/openshift-passwd $user 'r3dh4t1!'  2>&1 | tee -a $LOGFILE
        done

        scp /tmp/openshift-passwd  ${FIRSTMASTER}:/etc/origin/openshift-passwd 2>&1 | tee -a $LOGFILE


        scp /tmp/openshift-passwd  ${FIRSTMASTER}:/etc/origin/openshift-passwd 2>&1 | tee -a $LOGFILE

fi

echo "-- Identity providers modified to:"  2>&1 | tee -a $LOGFILE
grep -i identity /etc/ansible/hosts   2>&1 | tee -a $LOGFILE


ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml  2>&1 | tee -a $LOGFILE

echo "---- Ansible playbook completed running, returning $?" 2>&1 | tee -a $LOGFILE



################################################################################
## Step 3 - Configure OpenShift
################################################################################
echo "---- Step 3 - Configure OpenShift"  2>&1 | tee -a $LOGFILE


echo "-- setting default namespace to use the infra region" 2>&1 | tee -a $LOGFILE
ssh ${FIRSTMASTER} "
oc get namespace default -o yaml > namespace.default.yaml
sed -i  '/annotations/ a \ \ \ \ openshift.io/node-selector: region=infra' namespace.default.yaml
oc replace -f namespace.default.yaml
"  2>&1 | tee -a $LOGFILE

echo "-- Manually Creating the Registry on the OpenShift environment" 2>&1 | tee -a $LOGFILE

export REGISTRY_IMAGE=`ssh infranode1.example.com "docker images" | grep ose-docker-registry | awk '{print $2}'`
echo "-- REGISTRY_IMAGE on infranode1 is ${REGISTRY_IMAGE}"  2>&1 | tee -a $LOGFILE

ssh ${FIRSTMASTER} "
oadm registry --create --service-account='registry' --images='registry.access.redhat.com/openshift3/ose-docker-registry:${REGISTRY_IMAGE}'
"   2>&1 | tee -a $LOGFILE


: <<'DEPRICATEDSECTION'

ssh ${FIRSTMASTER} "systemctl restart atomic-openshift-master ; systemctl status atomic-openshift-master | grep Active ; oc get nodes"


sleep 10;

## This is a bit of nasty code, but it does the trick.
## go through all the nodes, if one of them is not ready, "ALLNODESready" is set to false, test runs again.
export ALLNODESready="false";
while [ $ALLNODESready == "false" ] ; do
export ALLNODESready="true";
for node in ${ALLNODES}
 do
   echo "Testing Ready status for node $node" 2>&1 | tee -a $LOGFILE ;
   ssh ${FIRSTMASTER} "oc get nodes $node | grep -w Ready"
   if [ $? == 1 ]
    then
      echo "Node $node is not ready" 2>&1 | tee -a $LOGFILE ;
      echo ssh $node "systemctl restart atomic-openshift-node" 2>&1 | tee -a $LOGFILE ;
      ssh $node "systemctl restart atomic-openshift-node" 2>&1 | tee -a $LOGFILE ;
      sleep 10;
      ssh $node "systemctl status atomic-openshift-node" 2>&1 | tee -a $LOGFILE ;
      export ALLNODESready="false";
    else
      echo "Node $node is ready" 2>&1 | tee -a $LOGFILE ;
    fi
done
if [ $ALLNODESready == "false" ]
  then
  echo "waiting for node service to restart "
  sleep 10;
  ssh ${FIRSTMASTER} "systemctl restart atomic-openshift-master ; systemctl status atomic-openshift-master | grep Active ; oc get nodes"
  echo "waiting for master service to restart "
  sleep 10;
  fi
done


echo "---- Creating the registry and router" 2>&1 | tee -a $LOGFILE

echo 'Creating Router Certs'
export CA=/etc/origin/master
oadm ca create-server-cert --signer-cert=$CA/ca.crt \
        --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
        --hostnames='*.cloudapps-$guid.oslab.opentlc.com' \
        --cert=cloudapps.crt --key=cloudapps.key
cat cloudapps.crt cloudapps.key $CA/ca.crt > /etc/origin/master/cloudapps.router.pem

echo 'Creating Router'
oadm router trainingrouter --replicas=1 \
 --credentials='/etc/origin/master/openshift-router.kubeconfig' \
 --service-account=router --stats-password='r3dh@t1!' --images='registry.access.redhat.com/openshift3/ose-haproxy-router:v3.2.0.44'

sleep 5
echo checking pods after 5 seconds - they might not be up yet
oc get pods -o wide
"  2>&1 | tee -a $LOGFILE

echo "---- Creating users and projects and restarting OpenShift Master" 2>&1 | tee -a $LOGFILE
# Creating users and restarting OpenShift Master

for user in ${USERS}
    do \
echo "---- creating users: $USERS" 2>&1 | tee -a $LOGFILE
useradd $user
done

ssh ${FIRSTMASTER} "


for user in ${USERS}
    do \
echo "---- creating users: $USERS" 2>&1 | tee -a $LOGFILE
useradd $user
done


systemctl restart atomic-openshift-master
sleep 5
systemctl status atomic-openshift-master


#oadm new-project hello-openshift --display-name='Hello Openshift Lab Project' --node-selector='env=dev' --admin=${DEVUSER} --server=https://master1-$GUID.oslab.opentlc.com:8443
#oadm new-project hello-s2i --display-name='S2I Lab Project' --node-selector='env=dev' --admin=${DEVUSER} --server=https://master1-$GUID.oslab.opentlc.com:8443
#oadm new-project justanother --display-name='Just Another Lab Project' --node-selector='env=dev' --admin=${DEVUSER}
"  2>&1 | tee -a $LOGFILE
DEPRICATEDSECTION



################################################################################
## Step 4 - Post-Configure OpenShift (Metrics, Logging)
################################################################################
echo "---- Step 4 - Post-Configure OpenShift (Metrics, Logging)"  2>&1 | tee -a $LOGFILE

echo "-- Get the openshift_toolkit repo to deploy METRICS and LOGGING"  2>&1 | tee -a $LOGFILE

git clone https://github.com/sborenst/openshift_toolkit /root/.openshift_toolkit 2>&1 | tee -a $LOGFILE
cd /root/.openshift_toolkit
git checkout tags/1.0 2>&1 | tee -a $LOGFILE

echo "-- set the current context to the default project"  2>&1 | tee -a $LOGFILE
ssh ${FIRSTMASTER} "oc project default"  2>&1 | tee -a $LOGFILE


if [ $METRICS == "TRUE" ]
  then
    echo "Running Ansible playbook for Metrics, logs to ${LOGFILE}.metrics" | tee -a $LOGFILE
    ansible-playbook /root/.openshift_toolkit/ansible/metrics/metrics.yaml 2>&1 | tee -a $LOGFILE.metrics
fi

echo "-- Check pods in the openshift-infra project"  2>&1 | tee -a $LOGFILE
ssh ${FIRSTMASTER} "oc get pods -n openshift-infra  -o wide"  2>&1 | tee -a $LOGFILE

echo "-- set the current context to the default project"  2>&1 | tee -a $LOGFILE
ssh ${FIRSTMASTER} "oc project default"  2>&1 | tee -a $LOGFILE

if [ $LOGGING == "TRUE" ]
 then
  echo "Running Ansible playbook for Logging, logs to ${LOGFILE}.logging" | tee -a $LOGFILE
  ansible-playbook /root/.openshift_toolkit/ansible/logging/logging.yaml 2>&1 | tee -a $LOGFILE.logging
fi

echo "-- Check pods in the logging project"  2>&1 | tee -a $LOGFILE
ssh ${FIRSTMASTER} "oc get pods -n logging -o wide"  2>&1 | tee -a $LOGFILE

echo "-- set the current context to the default project"  2>&1 | tee -a $LOGFILE
ssh ${FIRSTMASTER} "oc project default ;"  2>&1 | tee -a $LOGFILE



echo "-- Update /etc/motd"  2>&1 | tee -a $LOGFILE

cat << EOF > /etc/motd
###############################################################################
Environment Deployment Started      : ${DATE}
###############################################################################
###############################################################################
Environment Deployment Is Completed : `date`
###############################################################################
###############################################################################

EOF



################################################################################
## Step 5 - Demo content deployment
################################################################################
echo "---- Step 5 - Demo content deployment"  2>&1 | tee -a $LOGFILE



if [ $DEMO == "TRUE" ]
  then
echo "-- Running /root/.opentlc.installer/Demo_Deployment_Script.sh"  2>&1 | tee -a $LOGFILE
/root/.opentlc.installer/Demo_Deployment_Script.sh 2>&1 | tee -a /root/.Demo.Deployment.log
echo "-- Finished running /root/.opentlc.installer/Demo_Deployment_Script.sh"  2>&1 | tee -a $LOGFILE
fi


echo "-- Update /etc/motd"  2>&1 | tee -a $LOGFILE

cat << EOF >> /etc/motd
###############################################################################
Demo Materials Deployment Completed : `date`
###############################################################################
EOF

echo "-- Update /etc/motd on all nodes"  2>&1 | tee -a $LOGFILE

for node in  ${ALLHOSTS}
do
   scp /etc/motd $node:/etc/motd  2>&1 | tee -a $LOGFILE
done
