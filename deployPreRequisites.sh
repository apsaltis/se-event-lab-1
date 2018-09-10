#!/bin/bash

getHiveServerHost () {
        HIVESERVER_HOST=$(curl -k -s -u $AMBARI_CREDS -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
        echo $HIVESERVER_HOST
}

captureEnvironment () {
	export ZK_HOST=$AMBARI_HOST
	export COMETD_HOST=$AMBARI_HOST
	HIVESERVER_HOST=$(getHiveServerHost)
	export HIVESERVER_HOST=$HIVESERVER_HOST
}

createTransactionHistoryTable () {
	HQL="CREATE TABLE IF NOT EXISTS transaction_history_$CLUSTER_NAME ( accountNumber String,
                                                    fraudulent String,
                                                    merchantId String,
                                                    merchantType String,
                                                    amount Double,
                                                    currency String,
                                                    isCardPresent String,
                                                    latitude Double,
                                                    longitude Double,
                                                    transactionId String,
                                                    transactionTimeStamp String,
                                                    distanceFromHome Double,                                                                          
                                                    distanceFromPrev Double)
	PARTITIONED BY (accountType String)
	CLUSTERED BY (merchantType) INTO 30 BUCKETS
	STORED AS ORC
	TBLPROPERTIES (\"transactional\"=\"true\");"
	
	# CREATE Customer Transaction History Table
	beeline -u jdbc:hive2://$HIVESERVER_HOST:10000/default -d org.apache.hive.jdbc.HiveDriver -e "$HQL" -n hive
}

createKafkaTopics () {
	/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper $ZK_HOST:2181 --topic incoming_transaction --replication-factor 1 --partitions 1 --create
	/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper $ZK_HOST:2181 --create --topic customer_validation --partitions 1 --replication-factor 1
}

createSAMCluster() {
	#Import cluster
	export CLUSTER_ID=$(curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/clusters -d '{"name":"'$CLUSTER_NAME'","description":"Demo Cluster","ambariImportUrl":"http://'$AMBARI_HOST':8080/api/v1/clusters/'$CLUSTER_NAME'"}'| grep -Po '\"id\":([0-9]+)'|grep -Po '([0-9]+)')

	#Import cluster config
	curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/cluster/import/ambari -d '{"clusterId":'$CLUSTER_ID',"ambariRestApiRootUrl":"http://'$AMBARI_HOST':8080/api/v1/clusters/'$CLUSTER_NAME'","password":"'$PASSWD'","username":"'$USERID'"}'
}

initializeSAMNamespace () {
	#Initialize New Namespace
	export NAMESPACE_ID=$(curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/namespaces -d '{"name":"dev","description":"dev","streamingEngine":"STORM"}'| grep -Po '\"id\":([0-9]+)'|grep -Po '([0-9]+)')

	#Add Services to Namespace
	curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/namespaces/$NAMESPACE_ID/mapping/bulk -d '[{"clusterId":'$CLUSTER_ID',"serviceName":"STORM","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HDFS","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HBASE","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"KAFKA","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"DRUID","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HDFS","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HIVE","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"ZOOKEEPER","namespaceId":'$NAMESPACE_ID'}]'
}

uploadSAMExtensions() {
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"TIMESTAMP_LONG","displayName":"TIMESTAMP_LONG","description":"Converts a String timestamp to Timestamp Long","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.time.ConvertToTimestampLong"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"GET_WEEK","displayName":"GET_WEEK","description":"For a given data time string, returns week of the input date","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.time.GetWeek"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"ABSOLUTE","displayName":"ABSOLUTE","description":"Given a negative or positive Double, returns positive value.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.math.Absolute"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"ADD","displayName":"ADD","description":"Returns the Sum of two Doubles.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.math.Add"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"SUBTRACT","displayName":"SUBTRACT","description":"Returns the Difference of two Doubles.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.math.Subtract"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"MULTIPLY","displayName":"MULTIPLY","description":"Returns the Product of two Doubles.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.math.Multiply"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"DIVIDE","displayName":"DIVIDE","description":"Returns the Quotient of two Doubles.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.math.Divide"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"GEODISTANCE","displayName":"GEODISTANCE","description":"Returns the geographic distance between two Geo Coordinates. The function takes 4 arguments of Double type in the following order: origin latitude, origin longitude, destination latitude, destination longitude. ","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.geo.GeoDistance"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"STRING_TO_DOUBLE","displayName":"STRING_TO_DOUBLE","description":"Given a String, returns Double.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.datatype.conversion.StringToDouble"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"STRING_TO_LONG","displayName":"STRING_TO_LONG","description":"Given a String, returns Long.","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.datatype.conversion.StringToLong"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs
	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor-0.0.5-jar-with-dependencies.jar http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/phoenix-enrich-credit-fraud.json
	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor-phoenix-upsert-0.0.1-SNAPSHOT-jar-with-dependencies.jar  http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/phoenix-upsert-credit-fraud.json
	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-sink-0.0.5-jar-with-dependencies.jar http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/cometd-sink-credit-fraud.json
	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor-inject-field-0.0.1-SNAPSHOT-jar-with-dependencies.jar http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/inject-field-credit-fraud.json
}

pushSchemasToRegistry (){		
	PAYLOAD="{\"name\":\"original_transaction\",\"type\":\"avro\",\"schemaGroup\":\"transaction\",\"description\":\"original transaction\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	PAYLOAD="{\"schemaText\":\"{\\\"type\\\":\\\"record\\\",\\\"name\\\":\\\"original_transaction\\\",\\\"fields\\\" : [{\\\"name\\\": \\\"accountNumber\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"accountType\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"merchantId\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"merchantType\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"transactionId\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"currency\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"amount\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"ipAddress\\\", \\\"type\\\": [\\\"null\\\",\\\"string\\\"]},{\\\"name\\\": \\\"latitude\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"longitude\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"transactionTimeStamp\\\", \\\"type\\\": \\\"string\\\"}]}\",\"description\":\"original event\"}"
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/original_transaction/versions
	PAYLOAD="{\"name\":\"incoming_transaction\",\"type\":\"avro\",\"schemaGroup\":\"transaction\",\"description\":\"incoming transaction\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	PAYLOAD="{\"schemaText\":\"{\\\"type\\\":\\\"record\\\",\\\"name\\\":\\\"original_transaction\\\",\\\"fields\\\" : [{\\\"name\\\": \\\"accountnumber\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"accounttype\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"merchantid\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"merchanttype\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"transactionid\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"currency\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"amount\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"ipaddress\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"latitude\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"longitude\\\", \\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"transactiontimestamp\\\", \\\"type\\\": \\\"string\\\"}]}\",\"description\":\"original event\"}"
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/incoming_transaction/versions
	PAYLOAD="{\"name\":\"customer_validation\",\"type\":\"avro\",\"schemaGroup\":\"transaction\",\"description\":\"customer validation\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	PAYLOAD="{\"schemaText\":\"{\\\"type\\\":\\\"record\\\",\\\"name\\\":\\\"customer_validation\\\",\\\"fields\\\": [{\\\"name\\\": \\\"source\\\",\\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"accountNumber\\\",\\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"transactionId\\\",\\\"type\\\": \\\"string\\\"},{\\\"name\\\": \\\"fraudulent\\\",\\\"type\\\": \\\"string\\\"}]}\",\"description\":\"customer validation event\"}"
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/customer_validation/versions
}

createHbaseTables () {
	#Create Hbase Tables
	echo "create 'HISTORY','0'" | hbase shell
}

createPhoenixTables () {
	#Create Phoenix Tables
	tee create_customer_tables.sql <<-'EOF'
CREATE TABLE IF NOT EXISTS CUSTOMERACCOUNT (ACCOUNTNUMBER VARCHAR PRIMARY KEY, 
FIRSTNAME VARCHAR, LASTNAME VARCHAR, AGE VARCHAR, GENDER VARCHAR,STREETADDRESS VARCHAR, CITY VARCHAR, STATE VARCHAR, ZIPCODE VARCHAR, LATITUDE DOUBLE, LONGITUDE DOUBLE, IPADDRESS VARCHAR, PORT VARCHAR, ACCOUNTTYPE VARCHAR, ACCOUNTLIMIT VARCHAR, ISACTIVE VARCHAR);
UPSERT INTO CUSTOMERACCOUNT VALUES('19123', 'Regina', 'Smith', '32', 'Female', '1234 Tampa Ave', 'Cherry Hill', 'NJ', '08003', 39.919512, -75.005711, '', '', 'VISA', '20000', 'true');
CREATE TABLE IF NOT EXISTS CUSTOMERPROFILE (ACCOUNTNUMBER VARCHAR NOT NULL, FEATURETYPE VARCHAR NOT NULL, MEAN DOUBLE, DEV DOUBLE CONSTRAINT PK PRIMARY KEY (ACCOUNTNUMBER, FEATURETYPE));
UPSERT INTO CUSTOMERPROFILE VALUES('19123','distance', 9.173712305, 5.968364997);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','time_delta', 5398.577075, 6968.79762);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','convenience_store', 16.87915743, 4.272822919);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','gas_station', 36.9679558, 7.226414921);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','clothing_store', 174.1947298, 72.17713403);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','electronics_store', 98.97291196, 29.0160567);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','entertainment', 39.4743295, 5.728492345);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','health_beauty', 84.07411631, 35.58637624);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','restaurant', 73.73396065, 38.0403594);
UPSERT INTO CUSTOMERPROFILE VALUES('19123','grocery_or_supermarket', 83.73396065, 32.0403594);
CREATE TABLE IF NOT EXISTS TRANSACTIONHISTORY (TRANSACTIONID VARCHAR NOT NULL PRIMARY KEY, ACCOUNTNUMBER VARCHAR, ACCOUNTTYPE VARCHAR, MERCHANTID VARCHAR, MERCHANTTYPE VARCHAR, FRAUDULENT VARCHAR, AMOUNT DOUBLE, CURRENCY VARCHAR, IPADDRESS VARCHAR, ISCARDPRESENT VARCHAR, LATITUDE DOUBLE, LONGITUDE DOUBLE, TRANSACTIONTIMESTAMP BIGINT, DISTANCEFROMHOME DOUBLE, DISTANCEFROMPREV DOUBLE);
EOF

	/usr/hdp/current/phoenix-client/bin/sqlline.py $ZK_HOST:2181:/hbase-unsecure create_customer_tables.sql
}

configureHiveACID () {
	echo "*********************************Configuring Hive ACID..."
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.support.concurrency" "true"
	sleep 1	
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.txn.manager" "org.apache.hadoop.hive.ql.lockmgr.DbTxnManager"
	sleep 1	
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.exec.dynamic.partition.mode" "nonstrict"
	sleep 1	
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.enforce.bucketing" "true"
	sleep 1	
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.compactor.worker.threads" "1"
	sleep 1	
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.compactor.initiator.on" "true"
}



export ROOT_PATH=~/se-event-lab-1
echo "*********************************ROOT PATH IS: $ROOT_PATH"

captureEnvironment
sleep 2

createTransactionHistoryTable
sleep 2

createKafkaTopics
sleep 2

createSAMCluster
sleep 2

initializeSAMNamespace
sleep 2

uploadSAMExtensions
sleep 2

pushSchemasToRegistry
sleep 2

createHbaseTables
sleep 2

createPhoenixTables
sleep 2

configureHiveACID
sleep 2

exit 0
