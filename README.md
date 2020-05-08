# OpsMgrDocker
Ops Manager Demo in Docker

### Step 1 
- Build and run the opsmgr_4.2 image
- will create network mongo and install OpsMgr 4.3 and Mongodb 4.2

### Step 2 
- Add host alias to 127.0.0.1 localhost as OpsMgr in /etc/hosts
- Login and configure OpsMgr 
  - Set the server to http://opsmgr:8080
  - Use a fake mail server, smtp, port 25, and use defaults for other values
  - Click on Admin to et up Backup DB blockstore (localhost:27017)

### Step 3 
- Under server, create an API key
- Add the Group and API key to the file 4.2_node/data/automation-agent.config

### Step 4 
- Wait for opsmgr to start
- Build and run the node_4.2 image
- For 3 nodes: 
    - run these commands: run 1; run 2; run 3

### Step 5
- Provision a cluster
