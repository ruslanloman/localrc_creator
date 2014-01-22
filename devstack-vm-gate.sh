#!/bin/bash -xe

# Script that is run on the devstack vm; configures and
# invokes devstack.

# Copyright (C) 2011-2012 OpenStack LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.
#put to job export 
export LOCALRC_BRANCH=${BRANCH}

export DEVSTACK_GATE_TEMPEST=${DEVSTACK_GATE_TEMPEST:-0}

# Set to 1 to run the devstack exercises
export DEVSTACK_GATE_EXERCISES=${DEVSTACK_GATE_EXERCISES:-0}

# Set to 1 to run postgresql instead of mysql
export DEVSTACK_GATE_POSTGRES=${DEVSTACK_GATE_POSTGRES:-0}

# Set to 1 to use zeromq instead of rabbitmq (or qpid)
export DEVSTACK_GATE_ZEROMQ=${DEVSTACK_GATE_ZEROMQ:-0}

# Set to qpid to use qpid, or zeromq to use zeromq.
# Default set to rabbitmq
export DEVSTACK_GATE_MQ_DRIVER=${DEVSTACK_GATE_MQ_DRIVER:-"rabbitmq"}

# Set to 1 to run tempest stress tests
export DEVSTACK_GATE_TEMPEST_STRESS=${DEVSTACK_GATE_TEMPEST_STRESS:-0}

# Set to 1 to run tempest heat slow tests
export DEVSTACK_GATE_TEMPEST_HEAT_SLOW=${DEVSTACK_GATE_TEMPEST_HEAT_SLOW:-0}

# Set to 1 to run tempest large ops test
export DEVSTACK_GATE_TEMPEST_LARGE_OPS=${DEVSTACK_GATE_TEMPEST_LARGE_OPS:-0}

# Set to 1 to run tempest smoke tests serially
export DEVSTACK_GATE_SMOKE_SERIAL=${DEVSTACK_GATE_SMOKE_SERIAL:-0}

# Set to 1 to explicitly enable tempest tenant isolation. Otherwise tenant isolation setting
# for tempest will be the one chosen by devstack.
export DEVSTACK_GATE_TEMPEST_ALLOW_TENANT_ISOLATION=${DEVSTACK_GATE_TEMPEST_ALLOW_TENANT_ISOLATION:-0}

# Set to 1 to enable Cinder secure delete.
# False by default to avoid dd problems on Precise.
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1023755
export DEVSTACK_CINDER_SECURE_DELETE=${DEVSTACK_CINDER_SECURE_DELETE:-0}

# Set to 1 to run neutron instead of nova network
# Only applicable to master branch
export DEVSTACK_GATE_NEUTRON=${DEVSTACK_GATE_NEUTRON:-1}

# Set to 1 to run nova in cells mode instead of the default mode
export DEVSTACK_GATE_CELLS=${DEVSTACK_GATE_CELLS:-0}

# Set to 1 to run ironic baremetal provisioning service.
export DEVSTACK_GATE_IRONIC=${DEVSTACK_GATE_IRONIC:-0}

# Set to 1 to run savanna
export DEVSTACK_GATE_SAVANNA=${DEVSTACK_GATE_SAVANNA:-0}

# Set to 0 to disable config_drive and use the metadata server instead
export DEVSTACK_GATE_CONFIGDRIVE=${DEVSTACK_GATE_CONFIGDRIVE:-1}

# Set the number of threads to run tempest with
export TEMPEST_CONCURRENCY=${TEMPEST_CONCURRENCY:-2}

# The following variables are set for different directions of Grenade updating
# for a stable branch we want to both try to upgrade forward n => n+1 as
# well as upgrade from last n-1 => n.
#
# i.e. stable/havana:
#   DGG=1 means stable/grizzly => stable/havana
#   DGGF=1 means stable/havana => master (or stable/icehouse if that's out)
export DEVSTACK_GATE_GRENADE=${DEVSTACK_GATE_GRENADE:-0}
export DEVSTACK_GATE_GRENADE_FORWARD=${DEVSTACK_GATE_GRENADE_FORWARD:-0}
export BASE=${BASE_DIR:-"/opt/stack"}


function user_create()
{
sudo mkdir -p $BASE
if ! grep 'stack' /etc/passwd &>/dev/null; then
sudo useradd -U -s /bin/bash -d $BASE -m stack
fi
TEMPFILE=`mktemp`
echo "stack ALL=(root) NOPASSWD:ALL" >$TEMPFILE
chmod 0440 $TEMPFILE
sudo chown root:root $TEMPFILE
sudo mv $TEMPFILE /etc/sudoers.d/50_stack_sh
sudo chown stack:stack -R /opt/stack
}

function setup_localrc() {




    DEFAULT_ENABLED_SERVICES=g-api,g-reg,key,n-api,n-crt,n-obj,n-cpu,n-sch,horizon,mysql,rabbit,sysstat
    DEFAULT_ENABLED_SERVICES+=,s-proxy,s-account,s-container,s-object,cinder,c-api,c-vol,c-sch,n-cond

    # Allow optional injection of ENABLED_SERVICES from the calling context
    if [ -z $ENABLED_SERVICES ] ; then
        MY_ENABLED_SERVICES=$DEFAULT_ENABLED_SERVICES
    else
        MY_ENABLED_SERVICES=$DEFAULT_ENABLED_SERVICES,$ENABLED_SERVICES
    fi

    if [ "$DEVSTACK_GATE_TEMPEST" -eq "1" ]; then
        MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,tempest
    fi

    # the exercises we *don't* want to test on for grenade
    SKIP_EXERCISES=boot_from_volume,bundle,client-env,euca

    if [ "$LOCALRC_BRANCH" == "stable/grizzly" ]; then
        if [ "$DEVSTACK_GATE_NEUTRON" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,quantum,q-svc,q-agt,q-dhcp,q-l3,q-meta
            echo "Q_USE_DEBUG_COMMAND=True" >>localrc
            echo "NETWORK_GATEWAY=10.1.0.1" >>localrc
        else
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,n-net
        fi
        if [ "$DEVSTACK_GATE_CELLS" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,n-cell
        fi

     elif [ "$LOCALRC_BRANCH" == "stable/havana" ]; then
        MY_ENABLED_SERVICES+=,c-bak
        # we don't want to enable services for grenade that don't have upgrade support
        # otherwise they can break grenade, especially when they are projects like
        # ceilometer which inject code in other projects

        if [ "$DEVSTACK_GATE_GRENADE" -ne "1" ]; then
            MY_ENABLED_SERVICES+=,heat,h-api,h-api-cfn,h-api-cw,h-eng
            MY_ENABLED_SERVICES+=,ceilometer-acompute,ceilometer-acentral,ceilometer-collector,ceilometer-api
        fi

        
        
        if [ "$DEVSTACK_GATE_NEUTRON" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,quantum,q-svc,q-agt,q-dhcp,q-l3,q-meta,q-lbaas,q-vpn,q-fwaas,q-metering
            echo "Q_USE_DEBUG_COMMAND=True" >>localrc
            echo "NETWORK_GATEWAY=10.1.0.1" >>localrc
        else
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,n-net
        fi
        if [ "$DEVSTACK_GATE_CELLS" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,n-cell
        fi
 
    else # master
        MY_ENABLED_SERVICES+=,c-bak
        # we don't want to enable services for grenade that don't have upgrade support
        # otherwise they can break grenade, especially when they are projects like
        # ceilometer which inject code in other projects
        if [ "$DEVSTACK_GATE_GRENADE" -ne "1" ]; then
            MY_ENABLED_SERVICES+=,heat,h-api,h-api-cfn,h-api-cw,h-eng
            MY_ENABLED_SERVICES+=,ceilometer-acompute,ceilometer-acentral,ceilometer-collector,ceilometer-api,ceilometer-alarm-notifier,ceilometer-alarm-evaluator,ceilometer-anotification
        fi
        if [ "$DEVSTACK_GATE_NEUTRON" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,quantum,q-svc,q-agt,q-dhcp,q-l3,q-meta,q-lbaas,q-vpn,q-fwaas,q-metering
            echo "Q_USE_DEBUG_COMMAND=True" >>localrc
            echo "NETWORK_GATEWAY=10.1.0.1" >>localrc
        else
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,n-net
        fi
        if [ "$DEVSTACK_GATE_CELLS" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,n-cell
        fi
        if [ "$DEVSTACK_GATE_IRONIC" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,ir-api,ir-cond
        fi
        if [ "$DEVSTACK_GATE_SAVANNA" -eq "1" ]; then
            MY_ENABLED_SERVICES=$MY_ENABLED_SERVICES,savanna
        fi
    fi

    cat <<EOF >>localrc
DEST=$BASE/$LOCALRC_OLDNEW
ACTIVE_TIMEOUT=90
BOOT_TIMEOUT=90
ASSOCIATE_TIMEOUT=60
TERMINATE_TIMEOUT=60
MYSQL_PASSWORD=secret
DATABASE_PASSWORD=secret
RABBIT_PASSWORD=secret
ADMIN_PASSWORD=secret
SERVICE_PASSWORD=secret
SERVICE_TOKEN=111222333444
SWIFT_HASH=1234123412341234
ROOTSLEEP=0
#ERROR_ON_CLONE=True
ENABLED_SERVICES=$MY_ENABLED_SERVICES
#SKIP_EXERCISES=$SKIP_EXERCISES
SERVICE_HOST=127.0.0.1
# Screen console logs will capture service logs.
SYSLOG=False
SCREEN_LOGDIR=$BASE/$LOCALRC_OLDNEW/screen-logs
LOGFILE=$BASE/$LOCALRC_OLDNEW/devstacklog.txt
VERBOSE=True
FIXED_RANGE=10.1.0.0/24
FIXED_NETWORK_SIZE=256
VIRT_DRIVER=$DEVSTACK_GATE_VIRT_DRIVER
SWIFT_REPLICAS=1
LOG_COLOR=False
#PIP_USE_MIRRORS=False
#USE_GET_PIP=1
# Don't reset the requirements.txt files after g-r updates
#UNDO_REQUIREMENTS=False
#CINDER_PERIODIC_INTERVAL=10
#export OS_NO_CACHE=True
EOF

    if [ "$DEVSTACK_CINDER_SECURE_DELETE" -eq "0" ]; then
        echo "CINDER_SECURE_DELETE=False" >>localrc
    fi

    if [ "$DEVSTACK_GATE_TEMPEST_HEAT_SLOW" -eq "1" ]; then
        echo "HEAT_CREATE_TEST_IMAGE=False" >>localrc
        # Use Fedora 20 for heat test image, it has heat-cfntools pre-installed
        echo "HEAT_FETCHED_TEST_IMAGE=Fedora-i386-20-20131211.1-sda" >>localrc
    fi

    if [ "$DEVSTACK_GATE_POSTGRES" -eq "1" ]; then
        cat <<\EOF >>localrc
disable_service mysql
enable_service postgresql
EOF
    fi

    if [ "$DEVSTACK_GATE_MQ_DRIVER" == "zeromq" ]; then
        echo "disable_service rabbit" >>localrc
        echo "enable_service zeromq" >>localrc
    elif [ "$DEVSTACK_GATE_MQ_DRIVER" == "qpid" ]; then
        echo "disable_service rabbit" >>localrc
        echo "enable_service qpid" >>localrc
    fi

    if [ "$DEVSTACK_GATE_VIRT_DRIVER" == "openvz" ]; then
        echo "SKIP_EXERCISES=${SKIP_EXERCISES},volumes" >>localrc
        echo "DEFAULT_INSTANCE_TYPE=m1.small" >>localrc
        echo "DEFAULT_INSTANCE_USER=root" >>localrc
        echo "DEFAULT_INSTANCE_TYPE=m1.small" >>exerciserc
        echo "DEFAULT_INSTANCE_USER=root" >>exerciserc
    fi

    if [ "$DEVSTACK_GATE_TEMPEST" -eq "1" ]; then
        # We need to disable ratelimiting when running
        # Tempest tests since so many requests are executed
        echo "API_RATE_LIMIT=False" >> localrc
        # Volume tests in Tempest require a number of volumes
        # to be created, each of 1G size. Devstack's default
        # volume backing file size is 10G.
        #
        # The 24G setting is expected to be enough even
        # in parallel run.
        echo "VOLUME_BACKING_FILE_SIZE=24G" >> localrc
        # in order to ensure glance http tests don't time out, we
        # specify the TEMPEST_HTTP_IMAGE address to be horrizon's
        # front page. Kind of hacky, but it works.
        echo "TEMPEST_HTTP_IMAGE=http://127.0.0.1/" >> localrc
    fi

    if [ "$DEVSTACK_GATE_TEMPEST_ALLOW_TENANT_ISOLATION" -eq "1" ]; then
        echo "TEMPEST_ALLOW_TENANT_ISOLATION=True" >>localrc
    fi

    if [ "$DEVSTACK_GATE_GRENADE" -eq "1" ]; then
        echo "DATA_DIR=/opt/stack/data" >> localrc
        echo "SWIFT_DATA_DIR=/opt/stack/data/swift" >> localrc
        if [ "$LOCALRC_OLDNEW" == "old" ]; then
            echo "GRENADE_PHASE=base" >> localrc
        else
            echo "GRENADE_PHASE=target" >> localrc
        fi
    else
        # Grenade needs screen, so only turn this off if we aren't
        # running grenade.
        echo "USE_SCREEN=False" >>localrc
    fi

    if [ "$DEVSTACK_GATE_TEMPEST_LARGE_OPS" -eq "1" ]; then
        # use fake virt driver and 10 copies of nova-compute
        echo "VIRT_DRIVER=fake" >> localrc
        # To make debugging easier, disabled until bug 1218575 is fixed.
        # echo "NUMBER_FAKE_NOVA_COMPUTE=10" >>localrc
        echo "TEMPEST_LARGE_OPS_NUMBER=50" >>localrc
    fi

    if [ "$DEVSTACK_GATE_CONFIGDRIVE" -eq "1" ]; then
        echo "FORCE_CONFIG_DRIVE=always" >>localrc
    else
        echo "FORCE_CONFIG_DRIVE=False" >>localrc
    fi
}

function clone_run_devstack()
{
        sudo git clone https://github.com/openstack-dev/devstack.git ${BASE}
        cd ${BASE}
        sudo git checkout -b ${LOCALRC_BRANCH}  origin/${LOCALRC_BRANCH}
}


user_create
clone_run_devstack
setup_localrc

echo "Running devstack"
sudo -H -u stack ./stack.sh
