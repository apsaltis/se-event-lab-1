# se-event-lab-1
Author: Alexander Martens

## Deploy the pre-requisites
1.  Log in to virtual machine where Ambari server is running
```
ssh -i .ssh/<private_key_pem_file> cloudbreak@<ambari_host>
```
2.  Change user to root
```
sudo -i
```
3.  Change user to root
```
git clone https://github.com/martensa/se-event-lab-1
```
4.  Execute the deployment script
```
cd se-event-lab-1
./deployPreRequisites.sh
```
5.  Start CometD messaging container
```
./startContainer.sh
```
## Go to NiFi UI


## Start Credit Card Transaction Simulator
1.  Log in to virtual machine where Ambari server is running
```
ssh -i .ssh/<private_key_pem_file> cloudbreak@<ambari_host>
```
2.  Change user to root
```
sudo -i
```
3.  Execute the start script
```
cd se-event-lab-1
./startSimulation.sh

## Go to Streaming Analytcis Manager UI
