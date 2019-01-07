#!/usr/bin/env bash

CGROUP_HOME='/sys/fs/cgroup'
PARSEC_HOME='/home/bhyoo/benchmarks/parsec-3.0/bin'
GROUP_NAME='test'

INPUT_SIZE='simmedium'
NUM_CORE=1
BOUND_CORES='24-25'
CFS_PERIOD=50000

function cycle_limit() {
	cfs_quota=$(( ${NUM_CORE} * ${CFS_PERIOD} * $1 / 100 ))
	echo ${cfs_quota} > "$CGROUP_HOME/cpu/$GROUP_NAME/cpu.cfs_quota_us"
}


if [[ $# -eq 1 ]]; then
	workload=$1
elif [[ $# -eq 0 ]]; then
	workload='streamcluster'
else
	(>&2 echo "Usage: $0 <workload_name>")
	exit 1
fi

echo "running ${workload} with input size ${INPUT_SIZE}"

# create cgroups
sudo cgcreate -a "$USER:`id -ng $UID`" -d 755 -f 644 -t "$USER:`id -ng $UID`" -s 644 -g "cpuset:$GROUP_NAME" -g "cpu:$GROUP_NAME"

# setup cgroups
echo ${BOUND_CORES} > "$CGROUP_HOME/cpuset/$GROUP_NAME/cpuset.cpus"
echo ${CFS_PERIOD} > "$CGROUP_HOME/cpu/$GROUP_NAME/cpu.cfs_period_us"
cycle_limit 100

echo perf stat -e instructions,cycles -x , -I 1 \
 "${PARSEC_HOME}/parsecmgmt -a run -p ${workload} -i ${INPUT_SIZE} -n ${NUM_CORE}"

# execute
cgexec --sticky -g cpuset:test -g cpu:test \
 perf stat -e instructions,cycles -x , -I 1 \
 "${PARSEC_HOME}/parsecmgmt" -a run -p ${workload} -i ${INPUT_SIZE} -n ${NUM_CORE} 2> "${workload}_${INPUT_SIZE}-$(($CFS_PERIOD / 1000))ms.log" &

sleep 0.8

for percentile in `seq 10 10 100`; do
	sleep 0.1
	echo "Cycle Limit: ${percentile}%"
	cycle_limit ${percentile}
done

wait