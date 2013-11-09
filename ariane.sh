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

function demeteorize {
    echo "====Demeteorizing===="
    demeteorizer -o $BUNDLE_DIR
}

NEWRELIC_COMMANDS=""
function newrelic {
    if [ $NEWRELIC_AGENT == "true" ];
    then
        pushd $BUNDLE_DIR > /dev/null

        echo -e "\n====New Relic agent===="
        echo -e "require('newrelic');\n" >> app.js

        GIT_REVISION=`git rev-parse HEAD`;

        NEWRELIC_COMMANDS="
            npm install newrelic;

            echo -e '\nNotifying New Relic of new deployment';

            curl -s -H 'x-api-key:$NEWRELIC_API_KEY'
                -d 'deployment[app_name]=$APP_NAME'
                -d 'deployment[description]=Ariane deployment'
                -d 'deployment[revision]=$GIT_REVISION'
                -d 'deployment[user]=$SSH_USER'
                https://rpm.newrelic.com/deployments.xml > /dev/null;
        ";
        popd > /dev/null

        echo "OK"
    fi;
}

function bundle {
    echo -e "\n====Bundling===="
    pushd $BUNDLE_DIR > /dev/null

    echo "require('./main.js');" >> app.js
    tar czf ../$BUNDLE_FILE *

    popd > /dev/null
    echo "Bundle ready"
}

function upload {
    echo -e "\n====Uploading===="
    scp $BUNDLE_FILE $SSH_HOST:/tmp
}

function deploy {
    echo -e "\n=====Deploying===="
    COMMANDS="
        cd $APPS_HOME/$APP_NAME;
        rm -rf *;

        cp /tmp/$BUNDLE_FILE .;
        tar xf $BUNDLE_FILE;

        mkdir public;
        mkdir tmp;

        npm install;

        $NEWRELIC_COMMANDS

        touch tmp/restart.txt;
    "

    if [ -n $APPS_USER ];
    then
        SSH_COMMAND="sudo su -c \"$COMMANDS\" $APPS_USER"
    else
        SSH_COMMAND=$COMMANDS
    fi

    ssh $SSH_USER@$SSH_HOST $SSH_COMMAND
}


echo -e "\nBrace yourself, ariane is going to launch your Meteor....\n"

cleanup
demeteorize
newrelic
bundle
upload
deploy
cleanup

echo -e "\nDone :) Your Meteor has been succesfully launched!\n"
