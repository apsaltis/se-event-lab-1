export HTTP_HOST=$(hostname -f)
export HTTP_PORT=8085
export ZK_HOST=$(hostname -f)
export ZK_PORT=2181
export TOMCAT_PORT=8098
export COMETD_HOST=$(hostname -f)
export COMETD_PORT=8099
export MAP_API_KEY=AIzaSyB64AUJeFrg-8WkqDHYo4WtGjOoU1pUPxQ
nohup java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=6006 -jar TransactionUI/TransactionMonitorUI-jar-with-dependencies.jar > TransactionMonitorUI.log 2>&1&
echo $! > TransactionMonitorUI.pid
