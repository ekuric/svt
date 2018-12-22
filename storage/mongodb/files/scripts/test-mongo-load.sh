#!/bin/bash

set -e

readonly NAMESPACE=${1}
readonly ITERATION=${2}
readonly THREADS=${3}
readonly WORKLOAD=${4}
readonly RECORDCOUNT=${5}
readonly OPERATIONCOUNT=${6}
readonly DISTRIBUTION=${7}



output_dir=$(dirname $0)

readonly MONGODB_IP=$(oc get svc -n ${NAMESPACE} | grep -v glusterfs | grep mongodb | awk '{print $3}')

if [[ ! -z "${benchmark_results_dir}" ]]; then
  output_dir="${benchmark_results_dir}"
fi

echo "NAMESPACE: ${NAMESPACE}"
echo "ITERATION: ${ITERATION}"
echo "THREADS: ${THREADS}"
echo "WORKLOADS: ${WORKLOAD}"
echo "RECORDCOUNT: ${RECORDCOUNT}"
echo "OPERATIONCOUNT: ${OPERATIONCOUNT}"
echo "DISTRIBUTION: ${DISTRIBUTION}" 

mkdir -p ${output_dir}/load_data
mkdir -p ${output_dir}/mongodb_data_size
mkdir -p ${output_dir}/mongodb_run_test 
mkdir -p ${output_dir}/mongodb_data_size_before_test
mkdir -p ${output_dir}/mongodb_pods_logs
# load phase 

for i in $(seq 1 ${ITERATION}); do 
	ADMIN_PASS=$(oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- env | grep MONGODB_ADMIN_PASSWORD | cut -d'=' -f2)
	oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo testdb -p "${ADMIN_PASS}" -u admin --authenticationDatabase "admin" --eval "db.dropDatabase()" 
	echo "database dropped.... sleep 10s"
	sleep 10 
	for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do 
		for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do 
			
			# get data size prior load step 
			# todo - fix case when loads are as workloada,workloadb ... 
			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo --eval  "db.stats(1024*1024*1024)" 127.0.0.1:27017/testdb -p redhat -u redhat > ${output_dir}/mongodb_data_size_before_test/mongodb_data_size_${load}_${NAMESPACE}.txt

			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb load mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb -p recordcount=${RECORDCOUNT} -p operationcount=${OPERATIONCOUNT} -p requestdistribution=${DISTRIBUTION} -p mongodb.writeConcern=strict 2>&1 | tee -a ${output_dir}/load_data/mongodb_load_data_${NAMESPACE}_${load}_threads_${thread}.txt

		# get db size after load step 
			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') -- scl enable rh-mongodb32 -- mongo --eval  "db.stats(1024*1024*1024)" 127.0.0.1:27017/testdb -p redhat -u redhat > ${output_dir}/mongodb_data_size/mongodb_data_size_${load}_${NAMESPACE}.txt
		done 
   	done 
done

# sort result 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do

		echo "Throughput" > ${output_dir}/result_${load}_threads_${thread}.txt 
		grep "Throughput" ${output_dir}/load_data/mongodb_*  | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_threads_${thread}.txt

	        
                # insert 
		echo "INSERT-95thPercentileLatency" > ${output_dir}/result_${load}_insert95lat_${thread}.txt 
		grep "\[INSERT\]\, 95thPercentileLatency" ${output_dir}/load_data/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_insert95lat_${thread}.txt

		
		echo "INSERT-99thPercentileLatency" > ${output_dir}/result_${load}_insert99lat_${thread}.txt      
		grep "\[INSERT\]\, 99thPercentileLatency" ${output_dir}/load_data/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_insert99lat_${thread}.txt

	done
	paste -d',' ${output_dir}/result_${load}_threads_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}.csv
	
	paste -d',' ${output_dir}/result_${load}_insert95lat_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}_insert95lat.csv
        paste -d',' ${output_dir}/result_${load}_insert99lat_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}_insert99lat.csv
	
	paste -d',' ${output_dir}/*.csv > ${output_dir}/Throughput_Load_lat_${load}.csv

done 


# draw result 

# get script 
#curl -o ${output_dir}/drawresults.py https://raw.githubusercontent.com/ekuric/openshift/master/postgresql/drawresults.py 
#for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
#	python ${output_dir}/drawresults.py -r ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}.csv -i ff -o ${output_dir}/ycsb_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT} -t "${load} - recordcount=${RECORDCOUNT} operationcount=${OPERATIONCOUNT}" -p bars -x "Test iteration" -y "Throughtput (ops/sec)" --series=${ITERATION} 
#done 
