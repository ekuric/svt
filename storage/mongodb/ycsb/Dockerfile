FROM docker.io/openjdk:8-jdk

ENV ycsb_version=0.12.0

RUN curl -O --location https://github.com/brianfrankcooper/YCSB/releases/download/${ycsb_version}/ycsb-${ycsb_version}.tar.gz

RUN tar xfz ycsb-${ycsb_version}.tar.gz
RUN mv ycsb-${ycsb_version} ycsb

RUN curl -o ycsb/workloads/workloada https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workloada
RUN curl -o ycsb/workloads/workloadb https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workloadb
RUN curl -o ycsb/workloads/workloadc https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workloadc

RUN curl -o ycsb/workloads/workloadd https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workloadd
RUN curl -o ycsb/workloads/workloade https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workloade
RUN curl -o ycsb/workloads/workloadf https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workloadf
RUN curl -o ycsb/workloads/workload_template https://raw.githubusercontent.com/ekuric/YCSB/ycsb_tests/workloads/workload_template 



WORKDIR /ycsb

RUN echo "hanging there ..." > fake.log
CMD ["tail", "-f", "fake.log"]
