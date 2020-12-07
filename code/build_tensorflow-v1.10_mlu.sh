#!/bin/bash
set -e

usage () {
    echo "usage:   $0 [option]"
    echo "option:     -g        Configure and build tensorflow with debug"
    echo "option:     -c        Configure only, will not build the whl package"
    echo "option:     -j n      Specify the number of jobs for bazel build"
    echo "option:     null      Configure and build tensorflow with release"
}

echo "=== env ================================================================="

if [[ ! ${TENSORFLOW_HOME} ]];then
  cd $( dirname ${BASH_SOURCE} )
  export TENSORFLOW_HOME=$(pwd)
  cd - > /dev/null
fi

export PYTHON_VERSION=`python --version 2>&1 | awk -F '[ .]' '{print "python"$2"."$3}'`
export PATH_TFVENV_MLU=${PATH_TFVENV_MLU:=${TENSORFLOW_HOME}/virtualenv_mlu}
export PYTHON_BIN_PATH=${PATH_TFVENV_MLU}/bin/${PYTHON_VERSION}
export PYTHON_LIB_PATH=${PATH_TFVENV_MLU}/lib/${PYTHON_VERSION}/site-packages
export CC_OPT_FLAGS=$([ -z $CC_OPT_FLAGS ] && echo "-march=native" || echo $CC_OPT_FLAGS)
export TF_NEED_JEMALLOC=1
export TF_NEED_GCP=0
export TF_NEED_HDFS=0
export TF_NEED_S3=0
export TF_NEED_GDR=0
export TF_ENABLE_XLA=0
export TF_NEED_OPENCL=0
export TF_NEED_CUDA=0
export TF_NEED_MKL=0
export TF_NEED_VERBS=0
export TF_NEED_MPI=0
export TF_CUDA_CLANG=0
export TF_CUDA_CONFIG_REPO=0
export TF_NEED_OFFLINE=1
export TF_NEED_AWS=0
export TF_NEED_ROCM=0
export TF_NEED_KAFKA=0
export TF_NEED_OPENCL_SYCL=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0

export TF_NEED_MLU=1
if [ -z ${NEUWARE_HOME} ]; then
    echo
    echo "Caution: env NEUWARE_HOME was NULL, use default NEUWARE_HOME [/usr/local/neuware] !"
    export NEUWARE_HOME="/usr/local/neuware"
    echo
    echo "Make sure the path tree of /usr/local/neuware like this:"
    echo "/usr/local/neuware"
    echo "              ├── include"
    echo "              │   ├── cnrt.h"
    echo "              │   ├── cnml.h"
    echo "              │   ├── cnplugin.h"
    echo "              └── lib64"
    echo "                  └── libcnml.so"
    echo "                  └── libcnrt.so"
    echo "                  └── libcnplugin.so"
    echo
    echo "To build android arm64 demos, you may need re-configure to generate third_party/mlu soft links:"
    echo "  1. export NEUWARE_HOME=/usr/local/neuware"
    echo "  2. bash build_tensorflow-v1.10_mlu.sh -c (or --no-build)"
    echo
fi

# install git hooks
if [[ ${TENSORFLOW_HOME} && -d ${TENSORFLOW_HOME}/.git && -d ${TENSORFLOW_HOME}/.git/hooks && -d ${TENSORFLOW_HOME}/tools/hooks ]]; then
    cp ${TENSORFLOW_HOME}/tools/hooks/* ${TENSORFLOW_HOME}/.git/hooks
fi

echo "=== config  ============================================================="

if [[ ! -f ${PATH_TFVENV_MLU}/bin/activate ]];then
  virtualenv --system-site-packages --python=${PYTHON_VERSION} ${PATH_TFVENV_MLU}
fi

if ! source ${PATH_TFVENV_MLU}/bin/activate; then
  1>&2 echo "ERROR: failed to activate python virtual environment"
  exit 1
fi

pip install -r ${TENSORFLOW_HOME}/requirements.txt --no-cache-dir

${TENSORFLOW_HOME}/configure

jobs_num=16
debug_flag=false
configure_only=false

while getopts ":gcj:" optname
do
  case "$optname" in
    "g")
      echo "Build debug version"
      debug_flag=true
      ;;
    "c")
      echo "Configure only"
      configure_only=true
      ;;
    "j")
      if [ $OPTARG -gt 0 ]; then
        jobs_num=$OPTARG
        echo "Build project with the limited cores of $jobs_num"
      else
        echo "Get an invalid core number : $OPTARG"
        echo "Use the default core number of $jobs_num"
      fi
      ;;
    "?")
      echo "Unkonwn opt of $optname"
      ;;
    *)
      echo "Unkonwn error while processing options"
      ;;
    esac
done

echo "=== build ==============================================================="
if [ $configure_only == true ] && [ $debug_flag == true ]; then
  echo "You should not specify configure_only and debug at the same time!!!"
  exit 1
fi

if [ $configure_only == true ]; then
  exit 0
fi

if [ -f "${TENSORFLOW_HOME}/tools/cpu_feature_helper.sh" ]; then
  source ${TENSORFLOW_HOME}/tools/cpu_feature_helper.sh
  cpu_feats=`cpu_feature_helper`
  [ -n "${cpu_feats}" ] && echo "CPU has feature " ${cpu_feats}
fi

if [ $debug_flag == true ]; then
  sed  -e 's/compression=zipfile.ZIP_DEFLATED)/compression=zipfile.ZIP_DEFLATED, allowZip64=True)/g' \
  -e "/zip.writestr(zinfo, fp.read())/d" \
  -e "s/with open(path, 'rb') as fp:/zip.write(path, arcname=zinfo.filename, compress_type=zipfile.ZIP_DEFLATED)/g" \
  -i ${PATH_TFVENV_MLU}/lib/${PYTHON_VERSION}/site-packages/wheel/archive.py
  bazel build //tensorflow/tools/pip_package:build_pip_package \
      --verbose_failures \
      -c dbg \
      --copt="-g" \
      --cxxopt="-g" \
      --strip=never \
      --config=monolithic \
      --config=mlu \
      --jobs=$jobs_num \
      ${cpu_feats} \
      ${TF_CODE_COVERAGE}
else
  bazel build //tensorflow/tools/pip_package:build_pip_package \
      --verbose_failures \
      -c opt \
      --config=monolithic \
      --config=mlu \
      --jobs=$jobs_num \
      ${cpu_feats} \
      ${TF_CODE_COVERAGE}
fi

${TENSORFLOW_HOME}/bazel-bin/tensorflow/tools/pip_package/build_pip_package ${PATH_TFVENV_MLU} --mlu

# Upgrade the whl package
pip install ${PATH_TFVENV_MLU}/tensorflow_mlu-1.14*whl -U --upgrade-strategy only-if-needed
