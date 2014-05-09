#!/bin/bash
#This script is a work in development and is not stable.
#This script requires curl and git to be installed
#Run this script using rogue's login shell under: sudo su - <user>

DATE=$(date)
RUBY_VERSION="2.0.0-p353"
FQDN="example.com"
CTX_GEOGIT="/geoserver/geogit/"
FILE_SETTINGS="/var/lib/geonode/rogue_geonode/rogue_geonode/settings.py"

INIT_ENV=$1
INIT_CMD=$2

init_user(){
  adduser rogue --disabled-password --home /home/rogue --shell /bin/bash
}

install_rvm(){
  curl -L https://get.rvm.io | bash -s stable
}

install_gems(){
  #
  rvm get stable
  rvm list known
  rvm install "ruby-$RUBY_VERSION"
  rvm --default use $RUBY_VERSION
  ruby -v
  #
  gem install chef --version 11.8.0 --no-rdoc --no-ri --conservative
  gem install solve --version 0.8.2
  gem install nokogiri --version 1.6.1
  gem install berkshelf --version 2.0.14 --no-rdoc --no-ri
  gem list
  #
}

install_geonode(){
  echo "install_geonode"
  if [[ "$FQDN" != "example.com" ]]; then
    #
    cd /opt
    git clone https://github.com/ROGUE-JCTD/rogue-chef-repo.git
    mkdir chef-run
    cp -r /opt/rogue-chef-repo/solo/* chef-run/
    cd chef-run
    sed -i "s/dev.rogue.lmnsolutions.com/$FQDN/g" dna.json
    chmod 755 run.sh
    #
    bash --login run.sh
  else
    echo "You need to set the FQDN variable before continuing."
  fi
}

init_remote(){
  if [[ $# -ne 5 ]]; then
    echo "Usage: init_remotes <user> <password> <repo_name> <remote_name> <remote_url>"
    return
  fi
  URL = "http://$FQDN$CTX_GEOGIT$1/remote?user=$1&password=$2&output_format=JSON&remoteName=$3&remoteURL=$4"
  echo $URL
}

add_server(){
  if [[ $# -ne 5 ]]; then
      echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD [tms] <name> <url>"
  else
      INIT_ENV=$1
      INIT_CMD=$2
      TYPE=$3
      NAME=$4
      URL=$5
      if [[ "$TYPE" == "tms" ]]; then
          JSON="{\"source\":{\"ptype\":\"gxp_tmssource\",\"name\":\"$NAME\",\"url\":\"$URL\"},\"visibility\":True}"
          LINE="MAP_BASELAYERS.APPEND($JSON)"
          #echo $LINE
          bash --login -c "echo \"$LINE\" >> $FILE_SETTINGS"
      else
          echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD [tms] <name> <url>"
      fi
  fi
}


if [[ "$INIT_ENV" = "prod" ]]; then
    
    if [[ "$INIT_CMD" == "user" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f init_user
            bash --login -c init_user
        fi
    
    elif [[ "$INIT_CMD" == "rvm" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_rvm
            bash --login -c install_rvm
        fi
    
    elif [[ "$INIT_CMD" == "gems" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_gems
            bash --login -c install_gems
        fi
    
    elif [[ "$INIT_CMD" == "geonode" ]]; then
        
        if [[ $# -ne 2 ]]; then
	    echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD"
        else
            export -f install_geonode
            bash --login -c install_geonode
        fi

    elif [[ "$INIT_CMD" == "server" ]]; then
        
        if [[ $# -ne 5 ]]; then
	    echo "Usage: cybergis-script-init-rogue.sh $INIT_ENV $INIT_CMD [tms] <name> <url>"
        else
            export -f add_server
            bash --login -c "add_server $INIT_ENV $INIT_CMD $3 \"$4\" \"$5\""
        fi
    else
        echo "Usage: cybergis-script-init-rogue.sh prod [use|rvm|gems|geonode|server]"
    fi

else
    echo "Usage: cybergis-script-init-rogue.sh [prod|dev] [use|rvm|gems|geonode|server]"
fi
