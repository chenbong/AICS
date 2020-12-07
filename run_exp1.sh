# 获取当前目录
code_dir=`pwd`/code

# MLU使用情况
cnmon

echo '实验环境准备中...'

# 解压实验环境
rm -rf /opt/AICSE-demo-student
cd /opt
tar -zxf AICSE-demo-student.tar.gz
cd /opt/AICSE-demo-student/env

# 环境初始化
source env.sh
source /opt/AICSE-demo-student/env/tensorflow-v1.10/virtualenv_mlu/bin/activate

# 验证cncc, cngdb是否可用
cncc --help
cngdb --help

read -s -n1 -p "环境准备完成, 按 任意键 继续执行 bangc 单算子测试 ... "



# 进入实验1的工程目录
cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/bangc/PluginPowerDifferenceOp/

# 实现 powerdiff 的 bangc 算子
# 补全文件 plugin_power_difference_kernel.h, plugin_power_difference_kernel.mlu
cp $code_dir/plugin_power_difference_kernel.h ./
cp $code_dir/plugin_power_difference_kernel.mlu ./
cp $code_dir/powerDiff.cpp ./

# make 编译
bash make.sh

# bangc 单算子测试
./power_diff_test

read -s -n1 -p "bangc 单算子测试 完成, 按 任意键 继续执行 tensorflow框架集成 ... "

# tf 框架集成
# 补全 plugin_power_difference_op.cc, cnplugin.h
cp $code_dir/plugin_power_difference_op.cc ./
cp $code_dir/cnplugin.h ./

# 拷贝此文件夹到 cnplugin 文件夹进行编译
cp -r /opt/AICSE-demo-student/demo/style_transfer_bcl/src/bangc/PluginPowerDifferenceOp /opt/AICSE-demo-student/env/Cambricon-CNPlugin-MLU270/pluginops/
# 替换头文件
cp /opt/AICSE-demo-student/env/Cambricon-CNPlugin-MLU270/pluginops/PluginPowerDifferenceOp/cnplugin.h /opt/AICSE-demo-student/env/Cambricon-CNPlugin-MLU270/common/include/

# 编译
cd /opt/AICSE-demo-student/env/Cambricon-CNPlugin-MLU270/
bash build_cnplugin.sh --mlu200

read -s -n1 -p "build_cnplugin.sh 编译完成, 按 任意键 继续执行 tensorflow 框架集成 ... "


# 替换 libcnplugin.so 文件
cp /opt/AICSE-demo-student/env/Cambricon-CNPlugin-MLU270/build/libcnplugin.so /opt/AICSE-demo-student/env/neuware/lib64/

# 替换头文件
cp /opt/AICSE-demo-student/env/Cambricon-CNPlugin-MLU270/common/include/cnplugin.h /opt/AICSE-demo-student/env/neuware/include/


# tensorflow 算子集成
# && 复制算子到tf的源码中?
# 具体的添加规则: /opt/AICSE-demo-student/demo/style_transfer_bcl/src/tf-implementation/tf-add-power-diff/readme.txt
cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/tf-implementation/tf-add-power-diff/

cp cwise_op_power_difference* /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/core/kernels/

cp BUILD /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/core/kernels/

cp mlu_stream.h /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/stream_executor/mlu/

cp mlu_lib_ops.* /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/stream_executor/mlu/mlu_api/lib_ops/

cp mlu_ops.h /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/stream_executor/mlu/mlu_api/ops/

cp power_difference.cc /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/stream_executor/mlu/mlu_api/ops/

cp math_ops.cc /opt/AICSE-demo-student/env/tensorflow-v1.10/tensorflow/core/ops/


# 退出虚拟环境
deactivate

# 重新编译
cd /opt/AICSE-demo-student/env/tensorflow-v1.10/
# 在执行前, 将build_tensorflow-v1.10_mlu.sh中89行jobs_num改为8，否则在编译过程中无法完成，这是由于内存较小导致的。

cp $code_dir/build_tensorflow-v1.10_mlu.sh ./

bash build_tensorflow-v1.10_mlu.sh

read -s -n1 -p "tf 编译完成, 按 任意键 继续执行 tensorflow 框架集成 ... "

# 重新进入虚拟环境
source virtualenv_mlu/bin/activate

# 单算子的框架测试
# 补全 power_difference_test_cpu.py, 完成 tf 的接口调用
cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/online_cpu/
cp $code_dir/power_difference_test_cpu.py ./

# tf cpu 单算子测试, c++ 71ms, numpy 219ms
bash clean.sh
python power_difference_test_cpu.py 

read -s -n1 -p "tf cpu 单算子测试完成, 按 任意键 继续执行 tensorflow 框架集成 ... "

# 补全 power_difference_test_bcl.py
cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/online_mlu/
cp $code_dir/power_difference_test_bcl.py ./

# tf mlu 单算子测试, BLC 142ms, op 220ms
bash clean.sh
python power_difference_test_bcl.py
read -s -n1 -p "tf mlu 单算子测试完成, 按 任意键 继续执行 tensorflow 框架集成 ... "

read -s -n1 -p "完成 tensorflow 框架集成 实验, 按任意键退出... "