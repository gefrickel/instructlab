# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4

ARG OS_VERSION_MAJOR=9
ARG BASE_IMAGE=quay.io/centos/centos:stream${OS_VERSION_MAJOR}

FROM ${BASE_IMAGE}

ARG OS_VERSION_MAJOR=9

ENV LD_LIBRARY_PATH=/usr/lib64:/usr/lib

ARG CUDA_VERSION=12.8.0
ARG CUDA_DASHED_VERSION=12-8
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_MINOR_VERSION=12.8
ARG CUDNN_MAJOR_VERSION=9

# /opt/app-root structure (same as s2i-core and ubi9/python-311)
ENV APP_ROOT=/opt/app-root \
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Python, pip, and virtual env settings
ARG PYTHON_VERSION=3.11
ENV PYTHON_VERSION=${PYTHON_VERSION} \
    PYTHON=python${PYTHON_VERSION} \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONIOENCODING=utf-8 \
    VIRTUAL_ENV=${APP_ROOT} \
    PS1="[instructlab \w]\$ "

ARG PIP_INDEX_URL=https://pypi.org/simple

ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

ENV TORCH_CUDA_ARCH_LIST="7.0 7.5 8.0 8.6 8.7 8.9 9.0+PTX"
ENV TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
ENV TORCH_CUDNN_V8_API_ENABLED=1

ARG INSTRUCTLAB_PKG="instructlab[cuda]"
ARG INSTRUCTLAB_VERSION=''

RUN dnf -y install --best --nodocs --setopt=install_weak_deps=False dnf-plugins-core \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf config-manager --enable crb \
    && dnf install -y --nodocs \
        alsa-lib \
        asciidoc \
        atlas \
        bzip2 \
        compat-openssl11 \
        docbook-dtds \
        docbook-style-xsl \
        file \
        findutils \
        gdb \
        git-core \
        glibc-headers \
        gnupg2 \
        libjpeg-turbo \
        libpng \
        libsndfile \
        libstdc++ \
        jq \
        libaio \
        librdmacm \
        libtiff \
        libtool \
        libuuid \
        libyaml \
        libxslt \
        llvm \
        make \
        ncurses \
        numactl \
        openblas \
        openblas-serial \
        openmpi \
        pango \
        protobuf-compiler \
        ${PYTHON} \
        ${PYTHON}-devel \
        ${PYTHON}-pip \
        ${PYTHON}-setuptools-wheel \
        skopeo \
        snappy \
        sudo \
        tk \
        unzip \
        valgrind \
        vim \
        wget \
        which \
        lmdb \
    && dnf clean all \
    && ${PYTHON} -m venv --upgrade-deps ${VIRTUAL_ENV} \
    && mkdir -p ${HOME}

ENV OPENMPI_HOME="/usr/lib64/openmpi"

ENV PATH="/${OPENMPI_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${OPENMPI_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${OPENMPI_HOME}/lib64:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${OPENMPI_HOME}/lib:${CUDA_HOME}/lib64:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${OPENMPI_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${OPENMPI_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${OPENMPI_HOME}/include:${CMAKE_INCLUDE_PATH}"

# Install packages from EPEL
RUN dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_VERSION_MAJOR}.noarch.rpm \
    && dnf config-manager --set-enabled epel \
    && dnf install -y --nodocs \
        --exclude=rust \
        jemalloc \
        llvm14-libs \
        zeromq \
    && dnf clean all

ENV PATH=/root/.local/bin:${PATH}

# Add NVIDIA repo for CUDA libraries
RUN if [ "$(arch)" == "aarch64" ] ; then CUDA_REPO_ARCH="sbsa" ; else CUDA_REPO_ARCH=$(arch) ; fi \
    && dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel${OS_VERSION_MAJOR}/${CUDA_REPO_ARCH}/cuda-rhel${OS_VERSION_MAJOR}.repo \
    && dnf config-manager --set-enabled cuda-rhel9-${CUDA_REPO_ARCH}

RUN dnf install -y --nodocs \
        cuda-compat-${CUDA_DASHED_VERSION} \
        cuda-minimal-build-${CUDA_DASHED_VERSION} \
        cuda-toolkit-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION} \
        libnccl \
        libcutensor2 \
    && dnf clean all \
    && ln -s /usr/lib64/libcuda.so.1 /usr/lib64/libcuda.so

# Define global NVIDIA environment variables

ENV _CUDA_COMPAT_PATH=/usr/local/cuda/compat
ENV CUDA_CACHE_DISABLE=1
ENV CUDA_HOME="/usr/local/cuda"
ENV CUDA_MODULE_LOADING="LAZY"
ENV CUDA_SELECT_NVCC_ARCH_FLAGS=${TORCH_CUDA_ARCH_LIST}
ENV CUDA_VERSION=${CUDA_VERSION}
ENV LIBRARY_PATH="/usr/local/cuda/lib64/stubs"
ENV NCCL_WORK_FIFO_DEPTH=4194304
ENV NUMBA_CUDA_DRIVER="/usr/lib64/libcuda.so.1"
ENV NVIDIA_CPU_ONLY=1
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility,video"
ENV NVIDIA_REQUIRE_CUDA=cuda>=9.0
ENV NVIDIA_REQUIRE_JETPACK_HOST_MOUNTS=""
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV USE_EXPERIMENTAL_CUDNN_V8_API=1

ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${CUDA_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${CUDA_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${CUDA_HOME}/include:${CMAKE_INCLUDE_PATH}"

# Install Intel oneAPI repository for Intel oneMKL
COPY containers/cuda/intel-oneapi.repo /etc/yum.repos.d/oneapi.repo
RUN dnf config-manager --set-enabled intel-oneapi

RUN dnf -y install --nodocs \
        intel-oneapi-mkl-core \
    && dnf clean all

# Define global Intel oneMKL environment variables
ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"

ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CMAKE_INCLUDE_PATH}"

COPY requirements-vllm-cuda.txt requirements-vllm-cuda.txt
RUN source ${VIRTUAL_ENV}/bin/activate \
    && if [ "${INSTRUCTLAB_VERSION}" != "" ] ; then \
        INSTRUCTLAB_PKG="${INSTRUCTLAB_PKG}==${INSTRUCTLAB_VERSION}" ; \
    fi \
    && pip install torch psutil \
    && pip install flash_attn --no-build-isolation \
    && pip install "${INSTRUCTLAB_PKG}" -C cmake.args="-DGGML_CUDA=on" -C cmake.args="-DGGML_NATIVE=off" \
    && pip install -r requirements-vllm-cuda.txt \
    && rm requirements-vllm-cuda.txt

ENV TORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${PYTORCH_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_AUDIO_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchaudio"

ENV PATH="${PYTORCH_AUDIO_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_DATA_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchdata"

ENV PATH="${PYTORCH_DATA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_TEXT_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchtext"

ENV PATH="${PYTORCH_TEXT_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_VISION_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchvision"

ENV PATH="${PYTORCH_VISION_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${CMAKE_INCLUDE_PATH}"

WORKDIR /instructlab

RUN dnf install -y nss_wrapper gettext tar gzip unzip git dnsutils skopeo wget iputils nmap-ncat screen btop

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" ; \
    unzip awscliv2.zip ; \
    mkdir ~/.aws ; \
    chmod 777 ~/.aws ; \
    ./aws/install

RUN curl https://rclone.org/install.sh | bash ; \
    mkdir -p ~/.config ; \
    mkdir -p ~/.config/rclone ; \
    touch ~/.config/rclone/rclone.conf

RUN curl -L -s \
    https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.16.8/openshift-client-linux-4.16.8.tar.gz \
    | tar -C /usr/local/bin/ -zxv oc kubectl ; \
    chmod +x /usr/local/bin/oc ; \
    chmod +x /usr/local/bin/kubectl

# ENTRYPOINT ["/bin/bash"]
ENTRYPOINT ["/bin/sh", "-c", "--" , "while true; do sleep 30; done;"]
