export HADOOP_PREFIX="/usr/local/hadoop"
export HADOOP_MAPRED_HOME=$HADOOP_PREFIX
export HADOOP_USER_NAME=hadoop
export HIVE_HOME="/usr/local/hive"
export SQOOP_HOME="/usr/local/sqoop"

export PATH=$PATH:$HADOOP_PREFIX/bin:$HIVE_HOME/bin:$SQOOP_HOME/bin

# Fix https://issues.apache.org/jira/browse/HIVE-8609
export HADOOP_USER_CLASSPATH_FIRST=true
