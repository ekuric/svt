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
	for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do 
		for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do 
			
			# test run 
			oc -n ${NAMESPACE} exec $(oc get pod -n ${NAMESPACE} | grep ycsb | awk '{print $1}') -- ./bin/ycsb run mongodb -s -threads $thread -P "workloads/${load}" -p mongodb.url=mongodb://redhat:redhat@${MONGODB_IP}:27017/testdb 2>&1 -p recordcount=${RECORDCOUNT} -p operationcount=${OPERATIONCOUNT} -p requestdistribution=${DISTRIBUTION} | tee -a ${output_dir}/mongodb_run_test/mongodb_run_load_${NAMESPACE}_${load}_threads_${thread}.txt
			# -p mongodb.writeConcern=strict - tested 

			# test finished ... get logs for mongodb pod 
			oc -n ${NAMESPACE} logs $(oc get pod -n ${NAMESPACE} | grep mongodb | awk '{print $1}') > ${output_dir}/mongodb_pods_logs/mongodb_logs_${NAMESPACE}.txt 
		done 
   	done 
done

# sort result 

for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
	for thread in $(echo ${THREADS} | sed -e s/,/" "/g); do

		echo "Throughput" > ${output_dir}/result_${load}_threads_${thread}.txt 
		grep "Throughput" ${output_dir}/mongodb_run_test/mongodb_*  | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_threads_${thread}.txt

	        
                # read 	
		echo "READ-95thPercentileLatency" > ${output_dir}/result_${load}_read95lat_${thread}.txt 
		grep "\[READ\]\, 95thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_read95lat_${thread}.txt

		
		echo "READ-99thPercentileLatency" > ${output_dir}/result_${load}_read99lat_${thread}.txt      
		grep "\[READ\]\, 99thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_read99lat_${thread}.txt

		# update 

		echo "UPDATE-95thPercentileLatency" > ${output_dir}/result_${load}_update95lat_${thread}.txt
                grep "\[UPDATE\]\, 95thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_update95lat_${thread}.txt
                echo "UPDATE-99thPercentileLatency" > ${output_dir}/result_${load}_update99lat_${thread}.txt
                grep "\[UPDATE\]\, 99thPercentileLatency" ${output_dir}/mongodb_run_test/mongodb_* | cut -d',' -f3 | cut -d' ' -f2 >> ${output_dir}/result_${load}_update99lat_${thread}.txt


	done
	paste -d',' ${output_dir}/result_${load}_threads_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}.csv
	
	paste -d',' ${output_dir}/result_${load}_read95lat_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}_read95lat.csv
        paste -d',' ${output_dir}/result_${load}_read99lat_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}_read99lat.csv
	
	paste -d',' ${output_dir}/result_${load}_update95lat_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}_update95lat.csv
        paste -d',' ${output_dir}/result_${load}_update99lat_* > ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}_update99lat.csv

	paste -d',' ${output_dir}/*.csv > ${output_dir}/Throughput_lat_${load}.csv

done 


# draw result 

# get script 
#curl -o ${output_dir}/drawresults.py https://raw.githubusercontent.com/ekuric/openshift/master/postgresql/drawresults.py 
#for load  in $(echo ${WORKLOAD} | sed -e s/,/" "/g); do
#	python ${output_dir}/drawresults.py -r ${output_dir}/result_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT}.csv -i ff -o ${output_dir}/ycsb_${load}_recordcount_${RECORDCOUNT}_operationcount_${OPERATIONCOUNT} -t "${load} - recordcount=${RECORDCOUNT} operationcount=${OPERATIONCOUNT}" -p bars -x "Test iteration" -y "Throughtput (ops/sec)" --series=${ITERATION} 
#done 
