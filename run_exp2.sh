# 获取当前目录
code_dir=`pwd`/code

read -s -n1 -p "环境准备完成, 按 任意键 继续执行 模型量化 ... "
# 模型量化
cd /opt/AICSE-demo-student/demo/style_transfer_bcl/tools/fppb_to_intpb
python fppb_to_intpb.py udnie_int8.ini

# 查看输出
ls /opt/AICSE-demo-student/demo/style_transfer_bcl/models/int_pb_models


read -s -n1 -p "模型量化完成, 按 任意键 继续执行 cpu推理 ... "
cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/online_cpu
# 补全cpu代码
cp $code_dir/transform_cpu.py ./

# 执行cpu推理
./clean.sh
./run.sh

# 查看输出结果
ls

read -s -n1 -p "cpu推理完成, 可在 /opt/AICSE-demo-student/demo/style_transfer_bcl/src/online_cpu 查看实验结果, 按 任意键 继续执行 mlu推理 ... "

cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/online_mlu
# 补全mlu代码
cp $code_dir/transform_mlu.py ./

# 执行mlu推理
./clean.sh
./run.sh

# 查看输出结果
ls

read -s -n1 -p "mlu推理完成, 可在 /opt/AICSE-demo-student/demo/style_transfer_bcl/src/online_mlu 查看实验结果, 按 任意键 继续执行 离线推理 ... "

cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/offline/src
cp $code_dir/inference.cpp ./

cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/offline/build
cmake ..
make

cd /opt/AICSE-demo-student/demo/style_transfer_bcl/src/offline
./run.sh

read -s -n1 -p "离线推理完成, 可在 /opt/AICSE-demo-student/demo/style_transfer_bcl/src/offline 查看实验结果, 按 任意键 退出 ... "

