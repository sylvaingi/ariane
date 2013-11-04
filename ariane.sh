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

cleanup

echo "====Demeteorizin'===="
demeteorizer -o $BUNDLE_DIR

echo "====Adding newrelic agent===="
pushd $BUNDLE_DIR > /dev/null
mv main.js app.js
echo -e "require('newrelic');\n" | cat - app.js > /tmp/app.js && mv /tmp/app.js .

echo "====Bundlin'===="
tar czf ../$BUNDLE_FILE *
popd > /dev/null

echo "====Sending Meteor bundle===="
scp $BUNDLE_FILE $SSH_HOST:/tmp

COMMANDS="    
    cd $APPS_HOME/$APP_NAME;
    rm -rf *;

    cp /tmp/$BUNDLE_FILE .;
    tar xf $BUNDLE_FILE;
    
    mkdir public;
    mkdir tmp;
    
    npm install;
    npm install newrelic;
    
    touch tmp/restart.txt;
"

echo "====Deploying bundle===="

if [ -n $APPS_USER ];
then
    SSH_COMMAND= "sudo su -c \"$COMMANDS\" $APPS_USER"
else
    SSH_COMMAND=$COMMANDS
fi

ssh $SSH_HOST $SSH_COMMAND

cleanup