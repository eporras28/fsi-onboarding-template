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
COPY contrib/wait_for_postgres.sh /var/lib/pgsql/wait_for_postgres.sh
USER root
RUN chmod 755 /var/lib/pgsql/provision_data.sh && chmod 755 /var/lib/pgsql/wait_for_postgres.sh
RUN chown postgres:root /var/lib/pgsql/provision_data.sh && chown postgres:root /var/lib/pgsql/wait_for_postgres.sh
USER postgres

#CMD ["run-postgresql", "&&", "/var/lib/pgsql/wait_for_postgres.sh", "/var/lib/pgsql/provision_data.sh"]
CMD "'run-postgresql' && '/var/lib/pgsql/wait_for_postgres.sh /var/lib/pgsql/provision_data.sh'"


