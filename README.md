# 3D Gaussian Splatting (3DGS) Windows 11 & RTX 4060 复现与工程评估

本仓库包含在 **Windows 11 + NVIDIA GeForce RTX 4060 (8GB VRAM)** 消费级硬件环境下，全链路复现与评估 3D Gaussian Splatting (3DGS) 算法的核心代码与预检工具。

##  项目亮点与工程改进

1. **环境闭环**：打通 MSVC 2022、CUDA 11.8 与 PyTorch 2.7.1 的 ABI 编译，成功构建 `diff-gaussian-rasterization` 与 `simple-knn` 扩展。
2. **防错门禁 (`preflight.py`)**：训练前自动执行数据正交划分断言，防止因漏传 `--eval` 导致评估阶段 `nan` 异常与数据泄漏。
3. **隔离化目录结构**：规范 `-m output/` 实验管理，避免多组实验参数交叉污染。

##  目录结构

```text
.
├── train.py                  # 训练主入口（已支持 --eval 正交校验）
├── render.py                 # 测试集/训练集离线批量渲染
├── metrics.py                # 自动计算 PSNR, SSIM, LPIPS 评估指标
├── preflight.py              # 训练前正交划分与路径哈希门禁
├── make_figures.py           # 逐像素误差热图与消融图表生成脚本
├── scene/                    # 相机与数据集解析模块
└── submodules/               # C++/CUDA 自定义扩展算子
