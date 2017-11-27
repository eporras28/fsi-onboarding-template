#
# PostgreSQL image for JBoss BPMSuite.
#
FROM centos/postgresql-95-centos7

MAINTAINER ddoyle <ddoyle@redhat.com>

#############################################
# Copy the data provisioning script.
# We will use that in a lifecycle hook to provision the DB when the container starts.
#############################################
#ADD
COPY contrib/provision_data.sh /var/lib/pgsql/provision_data.sh
