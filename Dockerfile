ARG GPU=gpu
FROM tensorflow/tensorflow:latest-devel${GPU:+-$GPU} AS build_image

LABEL maintainer="Saltball <yanbohan98@gmail.com>"

WORKDIR /
# Get and compile protobuf
ARG PROTOBUF_VERSION=3.17.3
# NEEDED docker build --build-arg TOMCAT_VERSION
RUN  wget https://github.com.cnpmjs.org/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.zip &&\
    unzip -q protobuf-cpp-${PROTOBUF_VERSION} &&\
    cd protobuf-${PROTOBUF_VERSION} &&\
    ./configure && make -j$(nproc) install

# compile tensorflow
ARG TF_SRC=/tensorflow_src
ARG TF_BINAR=/tensorflow_binaries
RUN mkdir -p ${TF_BINAR}/lib/&&\
    mkdir -p ${TF_BINAR}/include/ &&\
    cd ${TF_SRC}  &&\
    sed -i -e "s:\${TF_BINAR}:${TF_BINAR}:" tensorflow/core/platform/default/build_config/BUILD &&\
    mkdir -p ./bazel_output_base &&\
    export PYTHON_BIN_PATH=$(which python3) &&\
    # export PYTHON_LIB_PATH=${SP_DIR} &&\
    export USE_DEFAULT_PYTHON_LIB_PATH=1 &&\
    # Additional compute capabilities can be added if desired but these increase
    # the build time and size of the package.
    export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0,7.5,8.0,8.6" &&\
    export TF_NCCL_VERSION="" &&\
    export GCC_HOST_COMPILER_PATH="$(which gcc)" &&\
    export GCC_HOST_COMPILER_PREFIX=$(dirname "$(which gcc)") &&\


    # additional settings
    # do not build with MKL support
    export TF_NEED_MKL=0 &&\
    export CC_OPT_FLAGS="-march=nocona -mtune=haswell" &&\
    export TF_ENABLE_XLA=0 &&\
    export TF_NEED_OPENCL=0 &&\
    export TF_NEED_OPENCL_SYCL=0 &&\
    export TF_NEED_COMPUTECPP=0 &&\
    export TF_NEED_ROCM=0 &&\
    export TF_NEED_MPI=0 &&\
    export TF_DOWNLOAD_CLANG=0 &&\
    export TF_SET_ANDROID_WORKSPACE=0 &&\

    # CUDA details
    export TF_NEED_CUDA=1 &&\
    # export TF_CUDA_VERSION="${cuda_compiler_version}" &&\
    # export TF_CUDNN_VERSION="${cudnn}" &&\
    export TF_CUDA_CLANG=0 &&\
    export TF_NEED_TENSORRT=0 &&\

    ./configure &&\

    bazel ${BAZEL_OPTS} build \
    --copt=-march=nocona \
    --copt=-mtune=haswell \
    --copt=-ftree-vectorize \
    --copt=-fPIC \
    --copt=-fstack-protector-strong \
    --copt=-O2 \
    --cxxopt=-fvisibility-inlines-hidden \
    --cxxopt=-fmessage-length=0 \
    --linkopt=-zrelro \
    --linkopt=-znow \
    --linkopt="-L${PREFIX}/lib" \
    --verbose_failures \
    --config=opt \
    --config=cuda \
    --color=yes \
    --curses=no \
    --jobs=$(nproc)\
    --discard_analysis_cache\
    --nokeep_state_after_build\
    --notrack_incremental_state\
    //tensorflow:libtensorflow_cc.so &&\

    mkdir -p $PREFIX/lib  &&\
    cp -d bazel-bin/tensorflow/libtensorflow_cc.so* $PREFIX/lib/ &&\
    cp -d bazel-bin/tensorflow/libtensorflow_framework.so* $PREFIX/lib/ &&\
    cp -d $PREFIX/lib/libtensorflow_framework.so.2 $PREFIX/lib/libtensorflow_framework.so &&\
    mkdir -p $PREFIX/include &&\
    mkdir -p $PREFIX/include/tensorflow &&\
    # copy headers
    rsync -avzh --exclude '_virtual_includes/' --include '*/'  &&\--include '*.h' --include '*.inc' --exclude '*' bazel-bin/ $PREFIX/include/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' tensorflow/cc $PREFIX/include/tensorflow/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' tensorflow/core $PREFIX/include/tensorflow/ &&\
    rsync -avzh --include '*/' --include '*' --exclude '*.cc' third_party/ $PREFIX/include/third_party/ &&\
    rsync -avzh --include '*/' --include '*' --exclude '*.txt' bazel-work/external/eigen_archive/Eigen/ $PREFIX/include/Eigen/ &&\
    rsync -avzh --include '*/' --include '*' --exclude '*.txt' bazel-work/external/eigen_archive/unsupported/ $PREFIX/include/unsupported/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-work/external/com_google_protobuf/src/google/ $PREFIX/include/google/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-work/external/com_google_absl/absl/ $PREFIX/include/absl/ &&\


    ENV DPMD_DIR=/opt/deepmd-kit  
RUN mkdir /tensorflow_binaries &&\
    cd /${TF_DIR} 


FROM ubuntu:latest AS binaries
COPY --from=build_image tensorflow_binaries.tar.gz /


