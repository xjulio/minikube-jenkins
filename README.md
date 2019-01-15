# minikube-jenkins
The project shows how to deploy a custom Jenkins into a kubernetes cluster. The approach used was to modify the original Dockerfile from the official repository in github.

## Requirements
The minikube and kubect must be installed previously.

## Dockerfile
The original Dockerfile was modified to change the version, disable security wizard, register custom jobs.

### Plugins
The plugins are installed during the image build proccess, to modifiy edit the file **config/plugins.txt**

### Jobs
Two custom jobs are deployed on image build proccess:

- **config/jobs/dummy-pipeline_config.xml**: A dummy job only with echo command in each stage.
- **config/jobs/java-mvn-pipeline_config.xml**: A demo pipeline with 3 stages; preparation (git clone), build (spring boot maven build) and test (junit test execution)

These jobs are previously created on a running jenkins instance and their config.xml file configuration was saved and the directory structre created during the image build proccess:

Dockerfile session to configure jobs:

<pre>
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
</pre>

### Security
Jenkins 2 is locked by default. Every time a new Jenkins installation is being set up, it must be secured and a new administrator user must be created. For demonstration purpose this feature will be disabled.

This this behavior can be change by setting a property in the **JAVA_OPTS** environment variable:  "-Djenkins.install.runSetupWizard=false". This configuration will force Jenkins to start without launching the security setup wizard.

This configuration was made on Dockerfile:

<pre>
# Starting Jenkins unlocked - COMMENT to normal startup
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
</pre>

### Version
This custom image it's using the newest versionm but if yu want to change the version used, two things must be change on Dockerfile:

- JENKINS_VERSION: Jenkins version
- JENKINS_SHA: sha 256 hash from jenkins.war. The war file must be download from https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/ and collect the hash by executing the command:

`
shasum -a 256 jenkins-war-2.158.wa
`

These step only is required if another version diferrent from 2.158 must be used.

<pre>
# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.158}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=8ce9d48563b49e8390d31a63b81b0a45da77186071f503a56b1cc44ff1fb9a1a
</pre>

## How to execute
Clone the git repository:

`
git clone https://github.com/xjulio/minikube-jenkins.git
`

Enter the repository directory and execute the run.sh script:

`
cd minikube-jenkins && sh build-and-deploy.sh
`

if the minikube is not running, then the script will start.

This proccess will create a namespace called **jenkins**, build a custom jenkins image with tag **jenkins:custom** using the Dockerfile manifest and will create deployment/services using the yml definition on **services/jenkins.yml** file.

##Terraform
Terraform it's an Infrastructure as Code (IaC) tool, but only for demonstration purporse the deployment can be done by using it. The manifest are located on terraform folder.

The deployment can be done using terraform. Before execute terraform plan or apply commands, the docker images must be build, for this execute the build.sh script:

`
sh build.sh
`

Enter on terraform directory (assuming that you are in docker directory) and execute terraform plan/apply commands:

`
cd terraform
`

To verify if everything it's OK:

`
terraform plan
`

To create resources on k8s: 

`
terraform apply
`

## Testing
Check if the replicas was deployed correctly using the command:
`
kubectl get deployment --namespace=jenkins
`
<pre>
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
jenkins   1         1         1            1           32m
</pre>

The jenkins deployed on k8s using the NodePort, for this we must find the IP address/port of services executing the following command:

`
 minikube service list --namespace=jenkins
`

<pre>
|-----------|---------|-----------------------------|
| NAMESPACE |  NAME   |             URL             |
|-----------|---------|-----------------------------|
| jenkins   | jenkins | http://192.168.99.103:32229 |
|-----------|---------|-----------------------------|
</pre>

The ports presented on URL column are random and probably will be different from those shown in the table.

To test service, use the following command to open the service url ar browser:

`
minikube service jenkins --namespace=jenkins
`
