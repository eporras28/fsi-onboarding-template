# Red Hat JBoss BPM Suite & Entando Client Onboarding FSI Demo

A _Client Onboarding_ FSI Demo, developed in Red Hat JBoss BPM Suite and Entando, running on OpenShift.

*TODO*: Insert link to introduction video on Youtube.

## Use case

*TODO*: Describe the use-case.


## Running the demo

This demo runs both on local installations of OpenShift Origin and OpenShift Container Platform,
as well as OpenShift Enterprise, OpenShift Dedicated and OpenShift Online instances.

A provisioning script has been provided which fully automates the installation of this demo. The only prerequisit is a local `oc` client. The
demo is installed in the OpenShift environment to which the `oc` client is connected.

If you don't have a local installation of OpenShift on your machine, but do have a VirtualBox virtualization environment installed, you can also
build a demo VirtualMachine using the provided https://www.vagrantup.com[Vagrant] and https://www.ansible.com[Ansible scripts].


## Running on OpenShift

This section describes how to run this demo on your OpenShift environment. If you don't have an OpenShift environment (either locally or online)
available, please scroll down to the *Building the Virtual Machine* section.

### Prerequisites

. Install https://www.openshift.org/download.html[the oc client tools].

. Login into the OpenShift in which the demo needs to be provisioned. Depending on the installation you can login with:
.. `oc login <url>`: The `oc` client will ask for a username and password.
.. `oc login <url> <toke>`: The provided token is used for authentication.


NOTE: To copy-paste the login command and token, go to your OpenShift web console and look for _Help_ > _Command line tools_.

### Install demo

Use the provision scripts to setup, configure, build and deploy the demo on OpenShift:

```
./openshift/provision.sh setup client-onboarding
```


### Delete the OpenShift application and project

```
./openshift/provision.sh delete client-onboarding
```

### Run the demo

*TODO*: Describe how to run the demo


## Building the Virtual Machine

If you don't have an OpenShift environment available, you can also build a Virtual Machine with the full demo-environment (including OpenShift)
provisioned

### Prerequisites

. An installation of https://www.virtualbox.org[VirtualBox]
. A https://www.vagrantup.com[Vagrant] installation.
. The Vagrant VBGuest plugin needs to be installed. If you don't have this plugin installed, you can install it with the command: `vagrant plugin install vagrant-vbguest`
. An https://www.ansible.com[Ansible] installation.

### Building the VM

We've provided a [Vagrantfile](vagrant/Vagrantfile) which fully automates the installation of the VirtualMachine. Run the following command in
the directory in which you checked out this Git repository:
```
./vagrant/vagrant up
```

Vagrant uses the provided Ansible playbook [entando-client-onboarding-playbook.yml](vagrant/entando-client-onboarding-playbook.yml) to provision
the VM and install:
. Gnome
. Docker
. OpenShift
. Client Onboarding Demo
