# SPDX-License-Identifier: Apache-2.0

FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubi9
RUN dnf install -y python3.11 python3.11-devel git python3-pip make automake gcc gcc-c++
WORKDIR /instructlab
RUN python3.11 -m ensurepip
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
RUN dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && dnf repolist && dnf config-manager --set-enabled cuda-rhel9-x86_64 && dnf config-manager --set-enabled cuda && dnf config-manager --set-enabled epel && dnf update -y
RUN dnf install -y libcudnn8 nvidia-driver-NVML nvidia-driver-cuda-libs
RUN python3.11 -m pip install --force-reinstall nvidia-cuda-nvcc-cu12
RUN export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64" \
    && export CUDA_HOME=/usr/local/cuda \
    && export PATH="/usr/local/cuda/bin:$PATH" \
    && export XLA_TARGET=cuda120 \
    && export XLA_FLAGS=--xla_gpu_cuda_data_dir=/usr/local/cuda

ARG GIT_TAG=stable
RUN if [[ "$(uname -m)" != "aarch64" ]]; then export CFLAGS="-mno-avx"; fi && \
    CMAKE_ARGS="-DLLAMA_CUBLAS=on" python3.11 -m pip install -r https://raw.githubusercontent.com/instructlab/instructlab/${GIT_TAG}/requirements.txt --force-reinstall --no-cache-dir llama-cpp-python
RUN python3.11 -m pip install git+https://github.com/instructlab/instructlab.git@${GIT_TAG}

ENTRYPOINT ["/bin/sh", "-c", "--" , "while true; do sleep 30; done;"]

LABEL com.redhat.component="instructlab"
