FROM openjdk:8-jdk-stretch

RUN apt-get update && apt-get install -y git curl maven && rm -rf /var/lib/apt/lists/*

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.16.1
COPY scripts/tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

COPY scripts/init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.158}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=8ce9d48563b49e8390d31a63b81b0a45da77186071f503a56b1cc44ff1fb9a1a

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# Starting Jenkins unlocked - COMMENT to normal startup
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

ENV MAVEN_HOME /usr/share/maven/

# plugin management scripts
COPY scripts/plugins.sh /usr/local/bin/plugins.sh
COPY scripts/install-plugins.sh /usr/local/bin/install-plugins.sh
RUN chmod +x /usr/local/bin/*

# Maven config
COPY config/hudson.tasks.Maven.xml ${JENKINS_HOME} 
RUN chown -R ${user} "$JENKINS_HOME"

USER ${user}

# Jenkins scripts
COPY scripts/jenkins-support /usr/local/bin/jenkins-support
COPY scripts/jenkins.sh /usr/local/bin/jenkins.sh
COPY scripts/tini-shim.sh /bin/tini

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# copying plugins list
COPY config/plugins.txt /tmp

# installing plugin from a file
RUN install-plugins.sh `cat /tmp/plugins.txt`

# install plugins from a list  
#RUN /usr/local/bin/install-plugins.sh \  
#   dashboard-view:2.9.10 \  
#   pipeline-stage-view:2.4 \  
#   parameterized-trigger:2.32 \  
#   #bitbucket:1.1.5 \  
#   git:3.0.5 \  
#   github:1.26.0`


USER root

# Jobs configuration
ARG job_name_1="dummy-pipeline"  
ARG job_name_2="java-mvn-pipeline"

# Create the job workspaces  
RUN mkdir -p "$JENKINS_HOME"/workspace/${job_name_1}  
RUN mkdir -p "$JENKINS_HOME"/workspace/${job_name_2}

# Create the jobs folder recursively  
RUN mkdir -p "$JENKINS_HOME"/jobs/${job_name_1}  
RUN mkdir -p "$JENKINS_HOME"/jobs/${job_name_2}

# Add the custom configs to the container  
COPY config/jobs/${job_name_1}_config.xml "$JENKINS_HOME"/jobs/${job_name_1}/config.xml  
COPY config/jobs/${job_name_2}_config.xml "$JENKINS_HOME"/jobs/${job_name_2}/config.xml

# Create build file structure  
RUN mkdir -p "$JENKINS_HOME"/jobs/${job_name_1}/latest/  
RUN mkdir -p "$JENKINS_HOME"/jobs/${job_name_1}/builds/1/

# Create build file structure  
RUN mkdir -p "$JENKINS_HOME"/jobs/${job_name_2}/latest/  
RUN mkdir -p "$JENKINS_HOME"/jobs/${job_name_2}/builds/1/