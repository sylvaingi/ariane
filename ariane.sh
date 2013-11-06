#!/bin/bash

set -e

if [ -f ariane.pod.sh ];
then
   source ariane.pod.sh
else
   echo "No ariane.pod.sh in current directory, please provide one at the root of your Meteor app"
   exit -1
fi

BUNDLE_FILE="$APP_NAME-bundle.tar.gz"
BUNDLE_DIR=.bundle

function cleanup {
    rm -rf $BUNDLE_DIR
    rm -f $BUNDLE_FILE
}

echo -e "\nBrace yourself, ariane is going to launch your Meteor....\n"

cleanup


echo "====Demeteorizing===="
demeteorizer -o $BUNDLE_DIR


pushd $BUNDLE_DIR > /dev/null

NEWRELIC_NPM_COMMAND="";
if [ $NEWRELIC_AGENT == "true" ];
then
    echo -e "\n====New Relic agent===="
    
    echo -e "require('newrelic');\n" | cat - main.js > /tmp/main.js && mv /tmp/main.js .    
    
    NEWRELIC_NPM_COMMAND="npm install newrelic;"
    
    echo "OK"
fi;


echo -e "\n====Bundling===="

mv main.js app.js
tar czf ../$BUNDLE_FILE *
popd > /dev/null

echo "Bundle ready"


echo -e "\n====Uploading===="
scp $BUNDLE_FILE $SSH_HOST:/tmp


echo -e "\n=====Deploying===="
COMMANDS="    
    cd $APPS_HOME/$APP_NAME;
    rm -rf *;

    cp /tmp/$BUNDLE_FILE .;
    tar xf $BUNDLE_FILE;
    
    mkdir public;
    mkdir tmp;
    
    npm install;
    $NEWRELIC_NPM_COMMAND
    
    touch tmp/restart.txt;
"

if [ -n $APPS_USER ];
then
    SSH_COMMAND="sudo su -c \"$COMMANDS\" $APPS_USER"
else
    SSH_COMMAND=$COMMANDS
fi

ssh $SSH_HOST $SSH_COMMAND

echo -e "\nDone :) Your Meteor has been succesfully launched!"

cleanup