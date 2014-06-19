#!/bin/bash

engage_version=$1;

engage_filename=riskflo-engage-web-$engage_version.war
static_filename=riskflo-engage-static-$engage_version.war

read -p "Enter Artifactory Username: " wgetuid
read -s -p "Enter Artifactory Password: " wgetpwd

echo ""

wget --user=$wgetuid --password=$wgetpwd  http://artifactory.riskflo.com.au/repository/libs-release-local/com/riskflo/engage/riskflo-engage-web/$engage_version/$engage_filename
wget --user=$wgetuid --password=$wgetpwd  http://artifactory.riskflo.com.au/repository/libs-release-local/com/riskflo/engage/riskflo-engage-static/$engage_version/$static_filename
