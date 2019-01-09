#!/usr/bin/env bash

REMOTE_USER='dcslab'
REMOTE_HOST='bc2'
TEST_URL='http://147.46.240.226:8080/examples/servlets/nonblocking/numberwriter'

AB_RESULT_NAME1='single'
AB_RESULT_NAME2='multi'

NPB_HOME='/home/bhyoo/benchmarks/NPB3.3.1/NPB3.3-OMP'
NPB_WORKLOAD='mg'

TOMCAT_GROUP='web'
BG_GROUP='bg'

AVAILABLE_FREQUENCIES=(`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies`)
CYCLE_MIN=57
CYCLE_MAX=100
CYCLE_STEP_NUM=${#AVAILABLE_FREQUENCIES[@]}


if [[ $# -ne 1 ]]; then
	(>&2 echo "Usage: $0 (dvfs|cycle)")
	exit 1
elif [ "$1" = "dvfs" ]; then
	expr_type=0
elif [ "$1" = "cycle" ]; then
	expr_type=1
else
	(>&2 echo "Usage: $0 (dvfs|cycle)")
	exit 1
fi


function run_cmd_on_remote() {
	ssh ${REMOTE_USER}@${REMOTE_HOST} -t "$1" &
}

function adjust_cycle_limit() {
	period=`cgget -nvr cpu.cfs_period_us ${BG_GROUP}`
	# FIXME: hard coded
	core_count=8
	cgset -r cpu.cfs_quota_us=`bc -l <<< "$period * $core_count * $1 / 100"` ${BG_GROUP}
}

function adjust_freq_to() {
	echo $1 | sudo tee "/sys/devices/system/cpu/cpu${2}/cpufreq/scaling_max_freq" > /dev/null
}


# setup cgroup for tomcat
group=`id -ng $UID`
sudo cgcreate -a $USER:$group -d 744 -f 644 -t $USER:$group -s 644 -g cpuset:${TOMCAT_GROUP} -g cpu:${TOMCAT_GROUP}
sudo cgclassify --sticky -g cpuset:${TOMCAT_GROUP} -g cpuset:${TOMCAT_GROUP} `ls /proc/$(cat /run/tomcat8.pid)/task | xargs`
# FIXME: hard coded
cgset -r cpuset.cpus='16-23' -r cpuset.memory_migrate='1' -r cpuset.memes='1' ${TOMCAT_GROUP}

# setup cgroup for bg
sudo cgcreate -a $USER:$group -d 744 -f 644 -t $USER:$group -s 644 -g cpuset:${BG_GROUP} -g cpu:${BG_GROUP}
cgset -r cpuset.cpus='24-31' -r cpuset.memory_migrate='1' -r cpuset.memes='1' ${BG_GROUP}


# run BG
cgexec -g cpuset:${BG_GROUP} -g cpu:${BG_GROUP} perf stat -e instructions,cycles -x , -I 1 env OMP_NUM_THREADS=8 ${NPB_HOME}/bin/${NPB_WORKLOAD}.C.x 2> bg_perf.log > ${NPB_WORKLOAD}.log &

# run FG
run_cmd_on_remote "ab -g /tmp/${AB_RESULT_NAME1}.tsv -n 200 -c 1 ${TEST_URL} > /tmp/${AB_RESULT_NAME1}.log"
child_pid1=$!
sleep 3
run_cmd_on_remote "ab -g /tmp/${AB_RESULT_NAME2}.tsv -n 500 -c 100 ${TEST_URL} > /tmp/${AB_RESULT_NAME2}.log"
child_pid2=$!


# DVFS
if [[ ${expr_type} -eq 0 ]]; then
	for freq in ${AVAILABLE_FREQUENCIES[@]}; do
		sleep 0.2

		echo "Set the frequency of 24~31 cores to ${freq}"
		for core_id in {24..31}; do
			adjust_freq_to $freq $core_id
		done
	done

# Cycle Limit
elif [[ ${expr_type} -eq 1 ]]; then
	for percentile in `seq ${CYCLE_MAX} $(bc -l <<< "-(${CYCLE_MAX} - ${CYCLE_MIN}) / ${CYCLE_STEP_NUM}") ${CYCLE_MIN}`; do
		sleep 0.2

		echo "Set cycle limit to ${percentile}%"
		adjust_cycle_limit $percentile
	done
fi


echo "Wait for the FG (${child_pid1}, ${child_pid2})"
wait $child_pid1 $child_pid2

echo 'Restore BG throttling'
if [[ ${expr_type} -eq 0 ]]; then
	for core_id in {24..31}; do
		adjust_freq_to ${AVAILABLE_FREQUENCIES[0]} $core_id
	done
elif [[ ${expr_type} -eq 1 ]]; then
	adjust_cycle_limit 100
fi


wait

scp -q "${REMOTE_USER}@${REMOTE_HOST}:/tmp/${AB_RESULT_NAME1}.*" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/${AB_RESULT_NAME2}.*" .
