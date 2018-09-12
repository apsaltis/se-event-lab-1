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
1. Upload NiFi template nifi-credit-fraud.xml (see NiFiFlow folder in this repository).

![Alt text](Screenshots/upload-template.png)

2. Add the uploaded template to the canvas per drag & drop.

![Alt text](Screenshots/add-template.png)

3. Review the entire flow and get a understanding of the single steps.
4. Resolve the two warnings at "QueryRecord" and “QueueIncomingTransaction” processors. Therefore, you need to go to Settings > Controller Services. 

![Alt text](Screenshots/nifi-settings.png)

Please edit the HortonworksSchemaRegistry service and update the host name of the Schema Registry URL. Then, you can enable this service and all the referencing components. 

![Alt text](Screenshots/controller-service.png)

The warnings should get resolved.
5. Update the Kafka broker URLs of both “QueueIncomingTransaction” processors with the appropriate host name.
6. Start the entire flow in NiFi.\n

![Alt text](Screenshots/nifi-start-flow.png)

## Go to Schema Registry UI
1. Make sure that the following schemas exists: original_transaction, incoming_transaction, customer_validation
2. Review the schemas for the different events in order to get a feeling about the data.

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
```

## Go to Streaming Analytcis Manager UI
