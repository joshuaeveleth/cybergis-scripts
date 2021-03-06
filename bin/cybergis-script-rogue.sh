#!/bin/bash
#This script is a work in development and is not stable.
#Dependencies: curl git
#Run this script using root's login shell under: sudo su -
#==================================#
DATE=$(date)
RUBY_VERSION="2.0.0-p353"
CTX_GEOGIG="/geoserver/geogig/"
FILE_SETTINGS="/var/lib/geonode/rogue_geonode/geoshape/settings.py"
#==================================#
INIT_ENV=$1
INIT_CMD=$2
#==================================#
#     Thes following functions are for installation #

init_user(){
  adduser rogue --disabled-password --home /home/rogue --shell /bin/bash
}

install_rvm(){
  curl -L https://get.rvm.io | bash -s stable
  #
  source /usr/local/rvm/scripts/rvm
  rvm get stable
  rvm list known
  rvm install "ruby-$RUBY_VERSION"
  rvm --default use $RUBY_VERSION
  ruby -v
  #
}

install_bundler(){
  #
  gem install bundler
  #
  #gem install chef --version 11.8.0 --no-rdoc --no-ri --conservative
  #gem install solve --version 0.8.2
  #gem install nokogiri --version 1.6.1
  #gem install berkshelf --version 2.0.14 --no-rdoc --no-ri
  #gem list
  #
}

install_gems(){
  if [[ $# -ne 2 ]]; then
    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
  else
    INIT_ENV=$1
    INIT_CMD=$2
    #
    echo "If the server stalls on installing GEMS, run <USE_SYSTEM_GECODE=1 gem install dep-selector-libgecode -v '1.0.2'> from the command line and then run again."
    cd /opt/rogue-chef-repo
    source /usr/local/rvm/scripts/rvm
    ############
    # lib gecode 14.04 fixes
    #apt-get install -y libgecode-dev
    mkdir /opt/gecode
    cd /opt/gecode
    wget http://ubuntu.cs.utah.edu/ubuntu/pool/main/b/boost1.46/libboost1.46-dev_1.46.1-7ubuntu3_amd64.deb
    wget http://ubuntu.cs.utah.edu/ubuntu/pool/main/b/boost-defaults/libboost-dev_1.48.0.2_amd64.deb
    wget http://ubuntu.cs.utah.edu/ubuntu/pool/universe/g/gecode/libgecode30_3.7.1-3_amd64.deb
    wget http://ubuntu.cs.utah.edu/ubuntu/pool/universe/g/gecode/libgecodegist30_3.7.1-3_amd64.deb
    wget http://ubuntu.cs.utah.edu/ubuntu/pool/universe/g/gecode/libgecodeflatzinc30_3.7.1-3_amd64.deb
    wget http://ubuntu.cs.utah.edu/ubuntu/pool/universe/g/gecode/libgecode-dev_3.7.1-3_amd64.deb
    dpkg -i *.deb
    dpkg -i libgecode-dev_3.7.1-3_amd64.deb
    apt-get -f install
    ############
    cd /opt/rogue-chef-repo
    USE_SYSTEM_GECODE=1 gem install dep-selector-libgecode -v '1.0.2'
    bundle install
    berks install
    berks vendor /opt/chef-run/cookbooks
    #
  fi
}


provision(){
  echo "provision"
  if [[ $# -ne 2 ]]; then
    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
  else
    INIT_ENV=$1
    INIT_CMD=$2
    #
    #
    cd /opt/chef-run
    chef-solo -c /opt/chef-run/solo.rb -j /opt/chef-run/dna.json
  fi
}

install_aws(){
  if [[ $# -ne 2 ]]; then
    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
  else
    #
    #if ! type "pip" &> /dev/null; then
    #    apt-get install python-pip
    #fi
    #pip install awscli
    #
    #The GeoGig Hook scripts uses the config info stored in settings.py instead of ~/.aws/config
    #aws configure
    #Install boto 9https://github.com/boto/boto) into Django's environment
    bash --login -c "/var/lib/geonode/bin/pip install -U boto"
  fi
}


#==================================#
#     The following functions are for configuration #

add_sns(){
  if [[ $# -ne 6 ]]; then
      echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <aws_access_key_id> <aws_secret_access_key> <sns_topic>"
  else
      INIT_ENV=$1
      INIT_CMD=$2
      AWS_ACCESS_KEY_ID=$3
      AWS_SECRET_ACCESS_KEY=$4
      SNS_TOPIC=$5
      FILE_SETTINGS=$6
      CMD1='echo "" >> "'$FILE_SETTINGS'"'
      CMD2='echo "AWS_ACCESS_KEY_ID = \"'$AWS_ACCESS_KEY_ID'\"" >> "'$FILE_SETTINGS'"'
      CMD3='echo "AWS_SECRET_ACCESS_KEY = \"'$AWS_SECRET_ACCESS_KEY'\"" >> "'$FILE_SETTINGS'"'
      CMD4='echo "AWS_SNS_TOPIC = \"'$SNS_TOPIC'\"" >> "'$FILE_SETTINGS'"'
      bash --login -c "$CMD1"
      bash --login -c "$CMD2"
      bash --login -c "$CMD3"
      bash --login -c "$CMD4"
  fi	
}

add_cron_sync(){
  if [[ $# -ne 10 ]]; then
      echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <direction> <user> <password> <localRepoName> <remoteName> <authorname> <authoremail> [hourly|daily|weekly|monthly]"
echo 'authorname and authoremail used when merging non-conflicting branches'
  else
      INIT_ENV=$1
      INIT_CMD=$2
      DIRECTION=$3
      USER=$4
      PASSWORD=${5}
      REPO=$6
      REMOTE=$7
      AUTHORNAME=$8
      AUTHOREMAIL=$9
      FREQUENCY=${10}
      #
      PASSWORD="$(echo "$PASSWORD" | sed -e 's/[()&]/\\&/g')"
      #
      CRON_FILE="/etc/cron.d/geogig_sync"
      LOG_FILE="/var/log/rogue/cron_geogig_sync.log"

      CMD='root /bin/bash /opt/cybergis-scripts.git/lib/rogue/geogig_sync.sh '$DIRECTION' '$USER' '$PASSWORD' \"'$REPO'\" '$REMOTE' \"'$AUTHORNAME'\" \"'$AUTHOREMAIL'\" >> '$LOG_FILE'" >> '$CRON_FILE

      if [[ "$FREQUENCY" == "hourly" ]]; then
          CMD='echo "@hourly '$CMD
          bash --login -c "$CMD"
      elif [[ "$FREQUENCY" == "daily" ]]; then
          CMD='echo "@daily '$CMD
          bash --login -c "$CMD"
      elif [[ "$FREQUENCY" == "weekly" ]]; then
          CMD='echo "@weekly '$CMD
          bash --login -c "$CMD"
      elif [[ "$FREQUENCY" == "monthly" ]]; then
          CMD='echo "@monthly '$CMD
          bash --login -c "$CMD"
      fi
      chmod 755 $CRON_FILE
  fi
}

add_cron_sync_2(){
  if [[ $# -ne 10 ]]; then
      echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <direction> <user> <password> <localRepoName> <remoteName> <authorname> <aithoremail> <frequency>"
      echo 'authorname and authoremail used when merging non-conflicting branches'
      echo 'frequency = a string in the crontab format = \"minute hour dayofmonth month dayofweek\"'
  else
      INIT_ENV=$1
      INIT_CMD=$2
      DIRECTION=$3
      USER=$4
      PASSWORD=${5}
      REPO=$6
      REMOTE=$7
      AUTHORNAME=$8
      AUTHOREMAIL=$9
      FREQUENCY=${10}
      #
      PASSWORD="$(echo "$PASSWORD" | sed -e 's/[()&]/\\&/g')"
      #
      CRON_FILE="/etc/cron.d/geogig_sync"
      LOG_FILE="/var/log/rogue/cron_geogig_sync.log"

      CMD='root /bin/bash /opt/cybergis-scripts.git/lib/rogue/geogig_sync.sh '$DIRECTION' '$USER' '$PASSWORD' \"'$REPO'\" '$REMOTE' \"'$AUTHORNAME'\" \"'$AUTHOREMAIL'\" >> '$LOG_FILE'" >> '$CRON_FILE

      if [[ "$FREQUENCY" != "" ]]; then
          CMD='echo "'$FREQUENCY' '$CMD
          bash --login -c "$CMD"
      fi
      chmod 755 $CRON_FILE
  fi
}

add_server(){
  if [[ $# -ne 6 ]]; then
      echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD [tms] <name> <url>"
  else
      INIT_ENV=$1
      INIT_CMD=$2
      TYPE=$3
      NAME=$4
      URL=$5
      FILE_SETTINGS=$6
      if [[ "$TYPE" == "tms" ]]; then
          JSON='{\"source\":{\"ptype\":\"gxp_tmssource\",\"name\":\"'$NAME'\",\"url\":\"'$URL'\"},\"visibility\":True}'
          LINE="MAP_BASELAYERS.append($JSON)"
          CMD1='echo "" >> "'$FILE_SETTINGS'"'
          CMD2='echo "'$LINE'" >> "'$FILE_SETTINGS'"'
          bash --login -c "$CMD1"
          bash --login -c "$CMD2"
      elif [[ "$TYPE" == "wms" ]]; then
          JSON='{\"source\":{\"ptype\":\"gxp_wmscsource\",\"restUrl\":\"/gs/rest\",\"name\":\"'$NAME'\",\"url\":\"'$URL'\"},\"visibility\":True}'
          LINE="MAP_BASELAYERS.append($JSON)"
          CMD1='echo "" >> "'$FILE_SETTINGS'"'
          CMD2='echo "'$LINE'" >> "'$FILE_SETTINGS'"'
          bash --login -c "$CMD1"
          bash --login -c "$CMD2"
      elif [[ "$TYPE" == "geonode" ]]; then
          JSON='{\"source\":{\"ptype\":\"gxp_wmscsource\",\"restUrl\":\"/gs/rest\",\"name\":\"'$NAME'\",\"url\":\"'$URL'/geoserver/wms\"},\"visibility\":True}'
          LINE="MAP_BASELAYERS.append($JSON)"
          CMD1='echo "" >> "'$FILE_SETTINGS'"'
          CMD2='echo "'$LINE'" >> "'$FILE_SETTINGS'"'
          bash --login -c "$CMD1"
          bash --login -c "$CMD2"
      else
          echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD [tms|geonode] <name> <url>"
      fi
  fi
}

add_remote(){
  echo $URL  
  if [[ $# -ne 10 ]]; then
      echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <user:password> <localRepoName> <localGeonodeURL> <remoteName> <remoteRepoName> <remoteGeoNodeURL> <remoteUser> <remotePassword>"
  else
      INIT_ENV=$1
      INIT_CMD=$2
      USERPASS=$3
      LOCAL_REPO_NAME=$4
      LOCAL_GEONODE_URL=$5
      REMOTE_NAME=$6
      REMOTE_REPO_NAME=$7
      REMOTE_GEONODE_URL=$8
      REMOTE_USER=$9
      REMOTE_PASS=${10}
      #
      REPO_URL="$LOCAL_GEONODE_URL/geoserver/geogig/$LOCAL_REPO_NAME/"
      REMOTE_URL="$REMOTE_GEONODE_URL/geoserver/geogig/$REMOTE_REPO_NAME/"
      CMD="add_remote_2 $INIT_ENV $INIT_CMD \"$USERPASS\" \"$REPO_URL\" \"$REMOTE_NAME\" \"$REMOTE_URL\" \"$REMOTE_USER\" \"$REMOTE_PASS\""
      bash --login -c "$CMD"
  fi
}

add_remote_2(){
  if [[ $# -ne 8 ]]; then
      echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <user:password> <repoURL> <remoteName> <remoteURL> <remoteUser> <remotePassword>"
  else
      INIT_ENV=$1
      INIT_CMD=$2
      USERPASS=$3
      REPO_URL=$4
      REMOTE_NAME=$5
      REMOTE_URL=$6
      REMOTE_USER=$7
      REMOTE_PASS=${8}
      #
      REMOTE_PASS="$(echo "$REMOTE_PASS" | sed -e 's/[()&]/\\&/g')"
      #
      CTX="remote"
      QS="user=$REMOTE_USER&password=$REMOTE_PASS&output_format=JSON&remoteName=$REMOTE_NAME&remoteURL=$REMOTE_URL"
      URL="$REPO_URL$CTX?$QS"
      
      CMD='curl -u '$USERPASS' "'$URL'"'
      #echo $CMD
      bash --login -c "$CMD"
  fi
}

osm(){
  if [[ $# -ne 6 ]]; then
      echo "Usage: cybergis-script-rogue.sh prod osm <user:password> <repo> <extent> <mapping>"
  else
      INIT_ENV=$1
      INIT_CMD=$2
      USERPASS=$3
      REPO=$4
      EXTENT=$5
      MAPPING=$6
      #
      if [ -d "/opt/cybergis-osm-mappings.git" ]; then
          EXTENT="$(echo "$EXTENT" | sed -e 's/[():]/\//g')"
          MAPPING="$(echo "$MAPPING" | sed -e 's/[():]/\//g')"
          FILE_EXTENT="/opt/cybergis-osm-mappings.git/extents/$EXTENT.txt"
          FILE_MAPPING="/opt/cybergis-osm-mappings.git/mappings/$MAPPING.json"
          if [ -f "$FILE_EXTENT" ] && [ -f "$FILE_MAPPING" ]; then
              VALUE_EXTENT=$(<$FILE_EXTENT)
              #
              #REPO_STAGING="/home/rogue/geogig/repo/$REPO"
              REPO_STAGING="/var/geogig/repo/$REPO"
              REPO_GEOSERVER="/var/lib/geoserver_data/geogig/$REPO"
              REPO_URL="http://localhost/geoserver/geogig/geonode:$REPO"
              #
              FILE_DATASTORE=/opt/cybergis-scripts.git/lib/rogue/post_geogig_datastore.xml
              FILE_LAYER=/opt/cybergis-scripts.git/lib/rogue/post_geogig_layer.xml
              #
              mkdir -p $REPO_STAGING
              cd $REPO_STAGING
              geogig init
              cp $FILE_MAPPING .
              #
              cp $FILE_DATASTORE .
              sed -i "s/{{name}}/$REPO/g" post_geogigdatastore.xml
              REPO_GEOSERVER_2="$(echo "$REPO_GEOSERVER" | sed -e 's/[()\/]/\\\//g')"
              sed -i "s/{{path}}/$REPO_GEOSERVER_2/g" post_geogigdatastore.xml
              #
              cp $FILE_LAYER .
              sed -i "s/{{name}}/$REPO/g" post_geogiglayer.xml
              #===============#
              CMD_1="geogig osm download --bbox $VALUE_EXTENT --mapping $FILE_MAPPING"
              echo $CMD_1
              bash --login -c "$CMD_1"
              cp -R $REPO_STAGING $REPO_GEOSERVER
              chown tomcat7:tomcat7 -R $REPO_GEOSERVER
              cd $REPO_STAGING
              geogig remote add -u admin -p admin origin $REPO_URL
              #===============#
              #Update GeoServer
              REST_DATASTORES="http://localhost/geoserver/rest/workspaces/geonode/datastores.xml"
              curl $REST_DATASTORES -u $USERPASS -H "Content-Type:text/xml" -XPOST -d @post_geogigdatastore.xml
              REST_LAYERS="http://localhost/geoserver/rest/workspaces/geonode/datastores/$REPO/featuretypes"
              curl $REST_LAYERS -u $USERPASS -H "Content-Type:text/xml" -XPOST -d @post_geogiglayer.xml
              #===============#
              #Update GeoNode
              #/var/lib/geonode/bin/python /var/lib/geonode/rogue_geonode/manage.py updatelayers --ignore-errors
              CRON_FILE="/etc/cron.d/geogig_sync_osm"
              LOG_FILE="/var/log/rogue/cron_geogig_sync_osm.log"
              ERROR_FILE="/var/log/rogue/cron_geogig_sync_osm_errors.log"
              CMD_CRON='root /bin/bash /opt/cybergis-scripts.git/lib/rogue/geogig_sync_osm.sh \"'$REPO_STAGING'\" origin \"'$LOGFILE'\" \"'$ERRORFILE'\" >> '$CRON_FILE
              echo $CMD_CRON
              if [[ "$FREQUENCY" != "" ]]; then
                  CMD='echo "'$FREQUENCY' '$CMD
                  echo $CMD
                  #bash --login -c "$CMD"
              fi
              #chmod 755 $CRON_FILE
          else
              echo "Could not find extent or mapping file"
              echo "Extent: $FILE_EXTENT"
              echo "Mapping: $FILE_MAPPING"
          fi
      else
          echo "cybergis-osm-mappings.git not found"
      fi
  fi
}


if [[ "$INIT_ENV" = "prod" ]]; then
    
    if [[ "$INIT_CMD" == "user" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f init_user
            bash --login -c init_user
        fi
    
    elif [[ "$INIT_CMD" == "rvm" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_rvm
            bash --login -c install_rvm
        fi
    
    elif [[ "$INIT_CMD" == "bundler" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_bundler
            bash --login -c install_bundler
        fi

    elif [[ "$INIT_CMD" == "gems" ]]; then

        if [[ $# -ne 2 ]]; then
            echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_gems
            bash --login -c "install_gems $INIT_ENV $INIT_CMD"
        fi

    
    elif [[ "$INIT_CMD" == "provision" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f provision
            bash --login -c "provision $INIT_ENV $INIT_CMD"
        fi

    elif [[ "$INIT_CMD" == "server" ]]; then
        
        if [[ $# -ne 5 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD [geonode|wms|tms] <name> <url>"
        else
            export -f add_server
            bash --login -c "add_server $INIT_ENV $INIT_CMD $3 \"$4\" \"$5\" \"$FILE_SETTINGS\""
        fi
    elif [[ "$INIT_CMD" == "remote" ]]; then
        
        if [[ $# -ne 10 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <user:password> <localRepoName> <localGeonodeURL> <remoteName> <remoteRepoName> <remoteGeoNodeURL> <remoteUser> <remotePassword>"
        else
            export -f add_remote
            export -f add_remote_2
            bash --login -c "add_remote $INIT_ENV $INIT_CMD \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" \"${10}\""
        fi
    elif [[ "$INIT_CMD" == "remote2" ]]; then
        
        if [[ $# -ne 8 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <user:password> <repoURL> <remoteName> <remoteURL> <remoteUser> <remotePassword>"
        else
            export -f add_remote_2
            bash --login -c "add_remote_2 $INIT_ENV $INIT_CMD \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\""
        fi
    elif [[ "$INIT_CMD" == "aws" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_aws
            bash --login -c "install_aws $INIT_ENV $INIT_CMD"
        fi
    elif [[ "$INIT_CMD" == "sns" ]]; then
        
        if [[ $# -ne 5 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <aws_access_key_id> <aws_secret_access_key> <sns_topic>"
        else
            export -f add_sns
            bash --login -c "add_sns $INIT_ENV $INIT_CMD \"$3\" \"$4\" \"$5\" \"$FILE_SETTINGS\""
        fi
    elif [[ "$INIT_CMD" == "cron" ]]; then
        
        if [[ $# -ne 10 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <direction> <user> <password> <localRepoName> <remoteName> <authorname> <authoremail> [hourly|daily|weekly|monthly]"
        else
            export -f add_cron_sync
            bash --login -c "add_cron_sync $INIT_ENV $INIT_CMD \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" \"${10}\""
        fi
    elif [[ "$INIT_CMD" == "cron2" ]]; then
        
        if [[ $# -ne 10 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <direction> <user> <password> <localRepoName> <remoteName> <authorname> <authoremail> <frequency>"
        else
            export -f add_cron_sync_2
            bash --login -c "add_cron_sync_2 $INIT_ENV $INIT_CMD \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" \"${10}\""
        fi
    elif [[ "$INIT_CMD" == "osm" ]]; then
        
        if [[ $# -ne 6 ]]; then
	    echo "Usage: cybergis-script-rogue.sh $INIT_ENV $INIT_CMD <user:password> <repo> <extent> <mapping>"
        else
            export -f osm
            bash --login -c "osm $INIT_ENV $INIT_CMD \"$3\" \"$4\" \"$5\" \"$6\""
        fi
    else
        echo "Usage: cybergis-script-rogue.sh prod [use|rvm|bundler|gems|provision|server|remote|remote2|aws|sns|cron|cron2|osm]"
    fi
else
    echo "Usage: cybergis-script-rogue.sh [prod|dev] [use|rvm|bundler|gems|provision|server|remote|remote2|aws|sns|cron|cron2|osm]"
fi

