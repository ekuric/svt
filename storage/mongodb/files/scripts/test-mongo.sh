#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly THREADS=${3}
readonly WORKLOAD=${4}

output_dir=$(dirname $0)

readonly MONGODB_IP=$(oc get svc -n ${NAMESPACE} | grep -v glusterfs | grep mongodb | awk '{print $3}')

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"

for i in $(seq 1 ${ITERATION}); do 
  for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do 
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do 
    		## TODO support to override other params
    		oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo -u redhat -p redhat ${MONGODB_IP}:27017/testdb --eval "db.usertable.remove({})"
		oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb load mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb 2>&1 | tee -a ${output_dir}/mongodb_load_data_${load}_threads_${thread}_run_${i}.txt
		# run test 
		oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb run mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb 2>&1 | tee -a ${output_dir}/mongodb_run_load_${load}_threads_${thread}_run_${i}.txt
		grep Throughput ${output_dir}/mongodb_run_load_${load}_threads_${thread}_run_${i}.txt | cut -d',' -f3 >> ${output_dir}/result_mongodb_run_load_${load}_threads_${thread}.txt
		#grep -E 'RunTime|Throughput' ${output_dir}/mongodb_run_load_${load}_threads_${THREADS}.txt >> ${output_dir}/result_mongodb_run_load_${load}_threads_${THREADS}.txt

	done 
   done 
done


# todo - draw results here ... 
