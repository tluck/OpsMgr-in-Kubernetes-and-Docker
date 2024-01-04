# OpsMgr K8s Demo

## In Kubernetes Summary:

TL;DR: To run the whole demo (assumes you have the GCP gcloud cli/api and other tools installed)
	
	git clone https://github.com/tluck/OpsMgr-in-Kubernetes-and-Docker.git
	cd OpsMgr-in-Kubernetes-and-Docker/k8s
	cp sample_init.conf init.conf
	./0_make_k8s.bash 
	./_launch.bash
	./_mc_launch.bash
	

This demo will install OM and a few MDB Clusters into a Kubernetes cluster.

- Ops Manager v6 is the current version.
  * Application DB - aka App DB - a Cluster for OM data
  * For Backup, 2 Clusters are built: a blockstore Cluster for data and an oplog Cluster for continous backups
- 2 Production Clusters
  * an example replica set cluster.
  * an example sharded cluster.
  * TLS Certs are created using a self-signed CA.
- An openLDAP server is included and configured to support OM users and/or DB users.
- There is the option to deploy a BiConnector for each cluster.
- And Queriable backup is available too!  

### Step 1. Configure a K8s Cluster
- Setup the K8s cluster
- Install the needed command tools: kubectl, cfssl (to generate a CA).

Note: see the multiCluster section below to create 4 seperate K8s clusters which can be used for this part.

	* Kubernetes - the demo is compatible with RH Openshift, Docker-Desktop, Minikube, AWS EKS, GCP K8S.
	* For a Production/Full Deployment:
		* 48-64 Cores
		* 192-256 GB Memory
		* 2000-5000 GB Disk 

	* Minimum resources required for a demo: 
		* 8 Cores
		* 11GB Memory (2GB of swap)
		* 50GB Disk 

### Step 2. Launch the Services
The **_launch.bash** script runs several "deploy" scripts for each of the following steps.

**Important** Before you run the **_launch.bash** script or any of the "deploy" scripts, copy the `sample_init.conf` file to `init.conf` and customize the parameters, such as adding your username (your email) and/or a new password. 

Note: For a simple demo, you may need to change serviceType to NodePort vs LoadBalancer. 

- Script 1: **deploy_Operator.bash**
	- Setup the environment in the namespace defined in init.conf
	- Deploys the MongoDB Enterprise K8s Operator
	- Deploys the Cert-Manager if TLS is on (default)

- Script 2: **deploy_OM.bash**
	- Setup the Ops Manager enviroment
  	- Deploy the OM Resources
  		- OpsManager
  		- AppDB
  	- Monitors the progress of OM for Readiness

- Script 3: **deploy_Cluster.bash** 
	- The script creates various TLS certificates, mdb users, secrets, and related configmaps. In other words, it deploys a cluster.
	- the _launch script deploys several MDB clusters. 
	- The Oplog and Blockstore ReplicaSet Clusters complete the Backup setup for OM
	- The cluster "myreplicaset" is a "Production" ReplicaSet Cluster and has a splitHorizon configuration for external cluster access
		- connect via `bin/connect_external.bash` script
	- The cluster "mysharded" is a "Production" Sharded Cluster using either NodePort or LoadBalancer for external cluster access
	- The script monitors the progress of the "mongodb" resource to attain "ready" before it exits.
	- Note: for convenience, the k8s cluster node names are used for the split horizon external access.
	
### Step 3. Login to Ops Manager
- To login to OM, connect with a browser using the user/password defined in `init.conf`.

	- The URL to OM depends on two things: 
		1. whethter TLS is used (default) and 
		2. the port exposure methods.  
	
	- When TLS is configured, use port 8443 (port 8080 is for a non-secure setup).
   		- If using a LoadBalancer, use: https://opsmanager-svc.mynamespace.svc.cluster.local:8443
   		- Or with NodePort, use: https://opsmanager-svc.mynamespace.svc.cluster.local:32443

   		Note: the actual URL will be shown along with the external name configured.
   		
- The admin user credentials and various other settings are held in `init.conf`
	- The scripts also create a hostname entry such as:
	
		`127.0.0.1       opsmanager-svc.<namespace>.svc.cluster.local`
	
		or
	
		`34.168.131.193	opsmanager-svc.mongodb.svc.mdb.com opsmanager-svc om.mongodb.mdb.com`
	
		into the ```/etc/hosts``` file for your convenience.

	- Note: Add the custom TLS certificate authority (certs/ca.crt) to your keystore. This will allow seamless unchallenged secure https access.
	
### Step 4: LDAP Server (Optional)
- Run ```bin/deploy_ldap.bash``` to create the server
   - This creates an openLDAP server and pre-configures OM for users and groups.
   - There are several DBusers: dbAdmin, User01, User02 (password is Mongodb1)
   - There are several OpsMgr Users: e.q Thomas.Luckenbach
   - There are 4 groups:
    	- dn: cn=dbadmins,ou=users,dc=example,dc=org
    	- dn: cn=dbusers,ou=users,dc=example,dc=org
    	- dn: cn=readers,ou=users,dc=example,dc=org
    	- dn: cn=managers,ou=users,dc=example,dc=org
	- The "manager" group is intended for configuring LDAP for OM users
	- The "dbusers" group is intended for configuring LDAP for DBusers
	- The "dbadmim" group is intended for configuring LDAP for DBadmins for clusterAdmin etc.

### Step 5: BiConnector Server (Optional)
- Run ```bin/deploy_BIC.bash -n <cluster> -p <NodePort> ``` to create the connector server 
   - This creates and configures a BiConnector server for a Cluster on NodePort N (e.g. 30307).

### Step 6: MultiCluster K8s resources (Optional)
- If you didn't already make multiple k8s clusters, run the ```0_make_k8s.bash``` to create 4 K8s in GCP.

	Note: this script builds a central cluster and 4 member clusters and then installs Istio mesh. The central cluster also has a VPC-wide DNS server.
- run ```_mc_launch.bash``` 
	- Creates two 5-node replicaSets across 3 the K8s "member" clusters - one is externally accessible using an external domain.
Note: this should be run afer you build OM resources as outlined above.



# Ops Manager Demo Environment (in Docker)
Docker Image Repo:     https://hub.docker.com/repository/docker/tjluckenbach/mongodb

## In Docker Summary:
These scripts run/deploy several containers in Docker. They create an OpsManager instance with severval agent-ready "empty nodes" to provision a cluster - leverage the Automation, Backup, etc.

### Step 1. StartUp OpsMgr (step1.bash)
- Build or pull the image (add -b option to build a new image with step1.bash script)
- Will create a docker network called mongonet and deploy OpsMgr and its AppDB

### Step 2. Configure OpsMgr and get API key for the agent (step2.bash)
- Add host alias to 127.0.0.1 localhost as OpsMgr in /etc/hosts
- Login and configure OpsMgr 
  - Set the server to http://opsmgr:8080
  - Use a fake mail server, smtp, port 25, and use defaults for other values
  - Click on Admin to et up Backup DB blockstore (localhost:27017)
- In OpsMgr, to the project and create an API key
- Add this Group key and API key to the file 6.x_node/data/automation-agent.config

### Step 3. Create the containers for a replicaSet - 3 nodes (step3.bash)
- Create some nodes - their agent will "register" with OM as available servers.
- For 3 nodes: 
    - run these commands: run 1; run 2; run 3

### Step 4.
- Login in to http://localhost:8080 (localhost)
- Provision a cluster on the 3 nodes
