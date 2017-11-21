#!/bin/sh
#!/bin/bash
set -e

command -v oc >/dev/null 2>&1 || {
  echo >&2 "The oc client tools need to be installed to connect to OpenShift.";
  echo >&2 "Download it from https://www.openshift.org/download.html and confirm that \"oc version\" runs.";
  exit 1;
}

################################################################################
# Provisioning script to deploy the demo on an OpenShift environment           #
################################################################################
function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [demo-name] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 setup --maven-mirror-url http://nexus.repo.com/content/groups/public/ --project-suffix s40d"
    echo
    echo "COMMANDS:"
    echo "   setup                    Set up the demo projects and deploy demo apps"
    echo "   deploy                   Deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo "   verify                   Verify the demo is deployed correctly"
    echo "   idle                     Make all demo services idle"
    echo
    echo "DEMOS:"
    echo "   client-onboarding        Red Hat JBoss BPM Suite & Entando 'Client Onboarding' FSI demo."
    echo
    echo "OPTIONS:"
    echo "   --binary                  Performs an OpenShift 'binary-build', which builds the WAR file locally and sends it to the OpenShift BuildConfig. Requires less memory in OpenShift."
    echo "   --user [username]         The admin user for the demo projects. mandatory if logged in as system:admin"
    echo "   --project-suffix [suffix] Suffix to be added to demo project names e.g. ci-SUFFIX. If empty, user will be used as suffix."
    echo "   --run-verify              Run verify after provisioning"
    echo "   --with-imagestreams       Creates the image streams in the project. Useful when required ImageStreams are not available in the 'openshift' namespace and cannot be provisioned in that 'namespace'."
    # TODO support --maven-mirror-url
    echo
}

ARG_USERNAME=
ARG_PROJECT_SUFFIX=
ARG_COMMAND=
ARG_RUN_VERIFY=false
ARG_BINARY_BUILD=false
ARG_WITH_IMAGESTREAMS=false
ARG_DEMO=

while :; do
    case $1 in
        setup)
            ARG_COMMAND=setup
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        deploy)
            ARG_COMMAND=deploy
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        delete)
            ARG_COMMAND=delete
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        verify)
            ARG_COMMAND=verify
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        idle)
            ARG_COMMAND=idle
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        --user)
            if [ -n "$2" ]; then
                ARG_USERNAME=$2
                shift
            else
                printf 'ERROR: "--user" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --project-suffix)
            if [ -n "$2" ]; then
                ARG_PROJECT_SUFFIX=$2
                shift
            else
                printf 'ERROR: "--project-suffix" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --run-verify)
            ARG_RUN_VERIFY=true
            ;;
        --binary)
            ARG_BINARY_BUILD=true
            ;;
        --with-imagestreams)
            ARG_WITH_IMAGESTREAMS=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *)               # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done


################################################################################
# Configuration                                                                #
################################################################################
LOGGEDIN_USER=$(oc whoami)
OPENSHIFT_USER=${ARG_USERNAME:-$LOGGEDIN_USER}

# Project name needs to be unique across OpenShift Online

PRJ_SUFFIX=${ARG_PROJECT_SUFFIX:-`echo $OPENSHIFT_USER | sed -e 's/[^-a-z0-9]/-/g'`}

PRJ=("client-onboarding-$PRJ_SUFFIX" "Client Onboarding" "Red Hat JBoss BPM Suite & Entando 'Client Onboarding' FSI Demo")
#PRJ_DISPLAY_NAME="Client Onboarding"
#PRJ_DESCRIPTION="Red Hat JBoss BPM Suite & Entando 'Client Onboarding' FSI Demo"
#GIT_URI="https://github.com/ge0ffrey/optashift-employee-rostering"
#GIT_URI="https://github.com/DuncanDoyle/optaplanner-openshift-worker-rostering" // TODO rename to optashift-employee-rostering
#GIT_REF="openshift-template"

# config
# TODO: Configure correct Github account.
GITHUB_ACCOUNT=${GITHUB_ACCOUNT:-entando}
GIT_REF=${GITHUB_REF:-master}
GIT_URI=https://github.com/$GITHUB_ACCOUNT/fsi-onboarding-bpm

################################################################################
# DEMO MATRIX                                                                  #
################################################################################
case $ARG_DEMO in
    client-onboarding)
	   # No need to set anything here anymore.
	;;
    *)
        echo "ERROR: Invalid demo name: \"$ARG_DEMO\""
        usage
        exit 255
        ;;
esac


################################################################################
# Functions                                                                    #
################################################################################

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}

function print_info() {
  echo_header "Configuration"

  OPENSHIFT_MASTER=$(oc status | head -1 | sed 's#.*\(https://[^ ]*\)#\1#g') # must run after projects are created

  echo "Demo name:           $ARG_DEMO"
  echo "OpenShift master:    $OPENSHIFT_MASTER"
  echo "Current user:        $LOGGEDIN_USER"
  echo "Project suffix:      $PRJ_SUFFIX"
  echo "GitHub repo:         $GIT_URI"
  echo "GitHub branch/tag:   $GITHUB_REF"
}

# waits while the condition is true until it becomes false or it times out
function wait_while_empty() {
  local _NAME=$1
  local _TIMEOUT=$(($2/5))
  local _CONDITION=$3

  echo "Waiting for $_NAME to be ready..."
  local x=1
  while [ -z "$(eval ${_CONDITION})" ]
  do
    echo "."
    sleep 5
    x=$(( $x + 1 ))
    if [ $x -gt $_TIMEOUT ]
    then
      echo "$_NAME still not ready, I GIVE UP!"
      exit 255
    fi
  done

  echo "$_NAME is ready."
}

# Create Project
function create_projects() {
  echo_header "Creating project..."

  echo "Creating project ${PRJ[0]}"
#  oc new-project $PRJ --display-name="$PRJ_DISPLAY_NAME" --description="$PRJ_DESCRIPTION" >/dev/null
  oc new-project "${PRJ[0]}" --display-name="${PRJ[1]}" --description="${PRJ[2]}" >/dev/null
}

function create_secrets() {
  pushd /tmp
  echo_header "Creating keystores..."
  # First remove the old keystores, otherwise the keytool script will complain.
  if [ -f keystore.jks ]; then
    rm keystore.jks
  fi
  if [ -f jgroups.jceks ]; then
    rm jgroups.jceks
  fi

  keytool -genkeypair -alias https -storetype JKS -keystore keystore.jks -storepass jboss@01 -keypass jboss@01 --dname "CN=jim,OU=BU,O=redhat.com,L=Raleigh,S=NC,C=US"
  keytool -genseckey -alias jgroups -storetype JCEKS -keystore jgroups.jceks -storepass jboss@01 -keypass jboss@01 --dname "CN=jim,OU=BU,O=redhat.com,L=Raleigh,S=NC,C=US"

  echo_header "Creating secrets..."
  oc create secret generic processserver-app-secret --from-file=jgroups.jceks --from-file=keystore.jks
  popd
}

function create_service_account() {
  echo_header "Creating Service Account..."
  oc create serviceaccount processserver-service-account

  echo_header "Adding policies..."
  oc policy add-role-to-user view system:serviceaccount:client-onboarding:processserver-service-account

  echo_header "Adding secrets to service account..."
  oc secret add sa/processserver-service-account secret/processserver-app-secret
}

function create_application() {
  echo_header "Creating Client Onboarding Build and Deployment config."
  # TODO: Introduce variables in the template if required.
  oc process -f templates/client-onboarding-process.yaml -p GIT_URI="$GIT_URI" -p GIT_REF="$GIT_REF" -n $PRJ | oc create -f - -n $PRJ

  # Don't need to patch, because the template we've used is already pre-patched.
  #echo_header "Patching the BuildConfig..."
  # Wait for the BuildConfig to become available
  #wait_while_empty "Build Config" 600 "oc get bc/co | grep co"
  #oc patch bc/co -p '{"spec":{"strategy":{"sourceStrategy":{"from":{"name":"jboss-processserver64-openshift:1.0"}}}}}'
#  oc process -f openshift/templates/client-onboarding-entando-template.yaml
# Entando instances creation
echo_header "Creating Entando instances fsi-customer and fsi-backoffice."

oc new-app https://github.com/pietrangelo/fsi-customer --name fsi-customer
oc expose svc fsi-customer --name=entando-fsi-customer
oc new-app https://github.com/pietrangelo/fsi-backoffice --name fsi-backoffice
oc expose svc fsi-backoffice --name=entando-fsi-backoffice

}

#function create_application_binary() {
#  echo_header "Creating Client Onboarding Build and Deployment config."
#  oc process -f openshift/templates/optashift-employee-rostering-template-binary.yaml -p GIT_URI="$GIT_URI" -p GIT_REF="$GIT_REF" -n $PRJ | oc create -f - -n $PRJ
#}

function build_and_deploy() {
  echo_header "Starting OpenShift build and deploy..."
  oc start-build co
#  oc start-build client-onboarding-entando
}

#function build_and_deploy_binary() {
#  start_maven_build
#
#  echo_header "Starting OpenShift binary deploy..."
#  oc start-build employee-rostering --from-file=target/ROOT.war
#}

function start_maven_build() {
    echo_header "Starting local Maven build..."
    mvn clean install -P openshift
}

function verify_build_and_deployments() {
  echo_header "Verifying build and deployments"

  # verify builds
  local _BUILDS_FAILED=false
  for buildconfig in optaplanner-employee-rostering
  do
    if [ -n "$(oc get builds -n $PRJ | grep $buildconfig | grep Failed)" ] && [ -z "$(oc get builds -n $PRJ | grep $buildconfig | grep Complete)" ]; then
      _BUILDS_FAILED=true
      echo "WARNING: Build $project/$buildconfig has failed..."
    fi
  done

  # verify deployments
  for project in $PRJ
  do
    local _DC=
    for dc in $(oc get dc -n $project -o=custom-columns=:.metadata.name,:.status.replicas); do
      if [ $dc = 0 ] && [ -z "$(oc get pods -n $project | grep "$dc-[0-9]\+-deploy" | grep Running)" ] ; then
        echo "WARNING: Deployment $project/$_DC in project $project is not complete..."
      fi
      _DC=$dc
    done
  done
}

function make_idle() {
  echo_header "Idling Services"
  oc idle -n $PRJ_CI --all
  oc idle -n $PRJ_TRAVEL_AGENCY_PROD --all
}

# GPTE convention
function set_default_project() {
  if [ $LOGGEDIN_USER == 'system:admin' ] ; then
    oc project default >/dev/null
  fi
}

################################################################################
# Main deployment                                                              #
################################################################################

if [ "$LOGGEDIN_USER" == 'system:admin' ] && [ -z "$ARG_USERNAME" ] ; then
  # for verify and delete, --project-suffix is enough
  if [ "$ARG_COMMAND" == "delete" ] || [ "$ARG_COMMAND" == "verify" ] && [ -z "$ARG_PROJECT_SUFFIX" ]; then
    echo "--user or --project-suffix must be provided when running $ARG_COMMAND as 'system:admin'"
    exit 255
  # deploy command
  elif [ "$ARG_COMMAND" != "delete" ] && [ "$ARG_COMMAND" != "verify" ] ; then
    echo "--user must be provided when running $ARG_COMMAND as 'system:admin'"
    exit 255
  fi
fi

#pushd ~ >/dev/null
START=`date +%s`

echo_header "Client Onboarding OpenShift Demo ($(date))"

case "$ARG_COMMAND" in
    delete)
        echo "Delete Client Onboarding demo ($ARG_DEMO)..."
        oc delete project $PRJ
        ;;

    verify)
        echo "Verifying Client Onboarding demo ($ARG_DEMO)..."
        print_info
        verify_build_and_deployments
        ;;

    idle)
        echo "Idling Client Onboarding OpenShift demo ($ARG_DEMO)..."
        print_info
        make_idle
        ;;

    setup)
        echo "Setting up and deploying Client Onboading demo ($ARG_DEMO)..."

        print_info
        create_projects

	create_secrets
	create_service_account

        if [ "$ARG_BINARY_BUILD" = true ] ; then
            create_application_binary
            build_and_deploy_binary
        else
            create_application
            #build starts automatically.
            #build_and_deploy
        fi

        if [ "$ARG_RUN_VERIFY" = true ] ; then
          echo "Waiting for deployments to finish..."
          sleep 30
          verify_build_and_deployments
        fi
        ;;

    deploy)
        echo "Deploying Client Onboarding demo ($ARG_DEMO)..."

        print_info

        if [ "$ARG_BINARY_BUILD" = true ] ; then
            build_and_deploy_binary
        else
            build_and_deploy
        fi

        if [ "$ARG_RUN_VERIFY" = true ] ; then
          echo "Waiting for deployments to finish..."
          sleep 30
          verify_build_and_deployments
        fi
        ;;

    *)
        echo "Invalid command specified: '$ARG_COMMAND'"
        usage
        ;;
esac

set_default_project
#popd >/dev/null

END=`date +%s`
echo
echo "Provisioning done! (Completed in $(( ($END - $START)/60 )) min $(( ($END - $START)%60 )) sec)"
