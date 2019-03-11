#!/usr/bin/env bash

username=$1
password=$2
opscpw=$3
dbpasswd=$4
nodecount=$5
ver=$6
studio=$7
cluster_name=$8

echo "Input to opsCenter.sh is:"
echo username $username
echo password XXXXXX
echo opscpw YYYYYY
echo dbpasswd ZZZZZZZ
echo nodecount $nodecount
echo ver $ver
echo studio $studio
echo cluster_name $cluster_name

# repo creds
repouser='datastax@microsoft.com'
repopw='3A7vadPHbNT'

release="7.3.0"
tar -xvf $release.tar.gz

cd install-datastax-ubuntu-$release/bin
# install extra packages, openjdk
./os/extra_packages.sh
./os/install_java.sh -o

# Overide OpsC install default version if needed
# export OPSC_VERSION='6.5.2'

#install opsc
./opscenter/install.sh 'azure'
# Turn on https, set pw for opsc user admin
./opscenter/set_opsc_pw_https.sh $opscpw
sleep 1m

datapath="/data/cassandra"

echo "Calling setupCluster.py with the settings:"
echo opsc_ip 127.0.0.1
echo cluster_name $cluster_name
echo username $username
echo password XXXXXX
echo repouser $repouser
echo repopw XXXXXX
echo datapath $datapath

# add --nojava to setupCluster call below,
# java must be installed on nodes separate from LCM
./lcm/setupCluster.py \
--opscpw $opscpw \
--clustername $cluster_name \
--repouser $repouser \
--repopw $repopw \
--dsever  $ver \
--user $username \
--password $password \
--dbpasswd $dbpasswd \
--datapath $datapath \
--nojava \
--verbose

# trigger install
./lcm/triggerInstall.py \
--opscpw $opscpw \
--clustername $cluster_name \
--clustersize $nodecount \
--pause 10 \
--trys 400

# Block execution while waiting for jobs to
# exit RUNNING/PENDING status
./lcm/waitForJobs.py \
--opscpw $opscpw
# set keyspaces to NetworkTopology / RF 3

echo "Backgrounding call to alterKeyspaces.py, writing ouput to repair.log... "
nohup ./lcm/alterKeyspaces.py \
--opscpw $opscpw \
--delay 60 >> ../../repair.log &

if [ "$studio" = "yes" ] ; then
    echo "Passed studio='yes', installing/starting studio"
    bash ../../studio.sh $username
fi
