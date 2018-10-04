# Edit this file to set custom options
# Tomcat accepts two parameters JAVA_OPTS and CATALINA_OPTS
# JAVA_OPTS are used during START/STOP/RUN
# CATALINA_OPTS are used during START/RUN

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CATALINA_HOME/lib
export LD_LIBRARY_PATH

CATALINA_PID=$CATALINA_BASE/logs/tomcat.pid

CATALINA_OPTS="-Xmx2G -Xms2G -XX:+AlwaysPreTouch  -Dspring.profiles.active=vpostgres,imagesInMongo,singleMongo,clusteredRabbit  -DRABBITMQ_HOSTS=AuctionMsg1:5672,AuctionMsg2:5672  -DMONGODB_HOST=AuctionNosql1 -DMONGODB_PORT=27017  -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:/opt/apache-tomcat-auction1/logs/gc.log"
