#!/bin/sh
#
#    Licensed to the Apache Software Foundation (ASF) under one or more
#    contributor license agreements.  See the NOTICE file distributed with
#    this work for additional information regarding copyright ownership.
#    The ASF licenses this file to You under the Apache License, Version 2.0
#    (the "License"); you may not use this file except in compliance with
#    the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
# chkconfig: 2345 20 80
# description: Apache NiFi is a dataflow system based on the principles of Flow-Based Programming.
#

# Script structure inspired from Apache Karaf and other Apache projects with similar startup approaches

export NIFI_DEFAULT_HOME=/opt/cloudera/parcels/NIFI
NIFI_HOME=${NIFI_HOME:-$CDH_NIFI_HOME}
export NIFI_HOME=${NIFI_HOME:-$NIFI_DEFAULT_HOME}

export JAVA="${JAVA_HOME}/bin/java"
export NIFI_CONF="${CONF_DIR}/conf"
export BOOTSTRAP_CONF="${NIFI_CONF}/bootstrap.conf";
export NIFI_PROPERTIES="${NIFI_CONF}/nifi.properties";
export NIFI_STATE_MANAGEMENT="${NIFI_CONF}/state-management.xml";
export NIFI_LIB="${NIFI_HOME}/lib"
export FQDN=$(hostname -f)

PROGNAME=`basename "$0"`

warn() {
    echo "${PROGNAME}: $*"
}

die() {
    warn "$*"
    exit 1
}

unlimitFD() {
    # Use the maximum available, or set MAX_FD != -1 to use that
    if [ "x$MAX_FD" = "x" ]; then
        MAX_FD="maximum"
    fi

    # Increase the maximum file descriptors if we can
    if [ "$os400" = "false" ] && [ "$cygwin" = "false" ]; then
        MAX_FD_LIMIT=`ulimit -H -n`
        if [ "$MAX_FD_LIMIT" != 'unlimited' ]; then
            if [ $? -eq 0 ]; then
                if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ]; then
                    # use the system max
                    MAX_FD="$MAX_FD_LIMIT"
                fi

                ulimit -n $MAX_FD > /dev/null
                # echo "ulimit -n" `ulimit -n`
                if [ $? -ne 0 ]; then
                    warn "Could not set maximum file descriptor limit: $MAX_FD"
                fi
            else
                warn "Could not query system maximum file descriptor limit: $MAX_FD_LIMIT"
            fi
        fi
    fi
}



locateJava() {
    if [ "x$JAVA" = "x" ] && [ -r /etc/gentoo-release ] ; then
        JAVA_HOME=`java-config --jre-home`
    fi
    if [ "x$JAVA" = "x" ]; then
        if [ "x$JAVA_HOME" != "x" ]; then
            if [ ! -d "$JAVA_HOME" ]; then
                die "JAVA_HOME is not valid: $JAVA_HOME"
            fi
            JAVA="$JAVA_HOME/bin/java"
        else
            warn "JAVA_HOME not set; results may vary"
            JAVA=`type java`
            JAVA=`expr "$JAVA" : '.* \(/.*\)$'`
            if [ "x$JAVA" = "x" ]; then
                die "java command not found"
            fi
        fi
    fi
}

update_config() {

    # Replace nifi.zookeeper.connect.string placeholder
    perl -pi -e "s#\#nifi.zookeeper.connect.string=\\{\\{QUORUM\\}\\}#nifi.zookeeper.connect.string=${ZK_QUORUM}#" $NIFI_PROPERTIES
    perl -pi -e "s#\\{\\{QUORUM\\}\\}#${ZK_QUORUM}#" $NIFI_STATE_MANAGEMENT
    perl -pi -e "s#\\{\\{NIFI_LIB\\}\\}#${NIFI_LIB}#" $NIFI_PROPERTIES
    perl -pi -e "s#\\{\\{FQDN\\}\\}#${FQDN}#" $NIFI_PROPERTIES

    #TEMP until this config is written by CDH
    cp "${CONF_DIR}/aux/bootstrap.conf" "$BOOTSTRAP_CONF"

    # replace placeholders with real values
    perl -pi -e "s#java=java#java=${JAVA}#" $BOOTSTRAP_CONF
    perl -pi -e "s#\#lib.dir=\\./lib#lib.dir=${NIFI_HOME}/lib#" $BOOTSTRAP_CONF
    perl -pi -e "s#\#conf.dir=\\./conf#conf.dir=${NIFI_CONF}#" $BOOTSTRAP_CONF

}

create_dirs() {
    test -d ${CONF_DIR}/lib || ln -s ${NIFI_HOME}/lib ${CONF_DIR}/lib
}

run() {
    echo
    echo "Java: ${JAVA}"
    echo "NiFi home directory: ${NIFI_HOME}"
    echo "Nifi conf directory: ${NIFI_CONF}"
    echo "Nifi conf directory: ${NIFI_LIB}"
    echo
    echo "Bootstrap config file: ${BOOTSTRAP_CONF}"
    echo "NIFI properties file: ${NIFI_PROPERTIES}"
    echo
    echo "Zookeper quorum: ${ZK_QUORUM}"
    echo

    exec "$JAVA" -cp "${CONF_DIR}":"$NIFI_HOME"/lib/bootstrap/* -Xms12m -Xmx24m -Dorg.apache.nifi.bootstrap.config.file="${BOOTSTRAP_CONF}" org.apache.nifi.bootstrap.RunNiFi $@
}

main() {
    create_dirs
    update_config
    run "$@"
}


case "$1" in
    start|stop|run|status|dump)
        main "$@"
        ;;
    restart)
        init
	run "stop"
	run "start"
	;;
    *)
        echo "Usage nifi {start|stop|run|restart|status|dump}"
        ;;
esac
