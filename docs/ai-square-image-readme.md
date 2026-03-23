# 镜像构建

## 基本环境

- 操作系统：Ubuntu 22.04.5 LTS
- Python 版本：3.12.3（`/root/miniconda3/bin/python`）
- PyTorch 版本：2.8.0+cu128
- CUDA 版本：12.8
- Node.js 版本：v22.19.0
- npm 版本：10.9.3
- ComfyUI：基于官方 `comfyanonymous/ComfyUI`，镜像内对应版本提交为 `04046049`
- 应用名称：`3lora 的 LTX2.3`

## 构建过程

### 代码 Clone

```bash
cd /root
git clone https://github.com/wojiushibuhui/3lora-ltx23-app.git /root/3lora-ltx23-app

# ComfyUI 运行目录
git clone https://github.com/comfyanonymous/ComfyUI.git /root/ComfyUI
cd /root/ComfyUI
git checkout 04046049
```

### 依赖安装

```bash
# 前端与服务端依赖
cd /root/3lora-ltx23-app
npm install

# ComfyUI 运行环境使用镜像内的 Miniconda Python
/root/miniconda3/bin/python --version

# 将 3lora 的 LTX2.3 覆盖层同步到 ComfyUI
cp -r /root/3lora-ltx23-app/comfyui-overlay/* /root/ComfyUI/
chmod +x /root/ComfyUI/start_comfyui_6006.sh
```

### 启动说明

```bash
# 启动 ComfyUI（6006）
cd /root/ComfyUI
bash /root/ComfyUI/start_comfyui_6006.sh

# 启动 3lora 的 LTX2.3 前后端服务（6008）
cd /root/3lora-ltx23-app
bash start-services.sh
```

## 环境验证代码

```bash
cd /root/3lora-ltx23-app

# 验证仓库代码可读
node -e "const pkg=require('./package.json'); console.log(pkg.name, pkg.version)"

# 验证 Python / Torch / CUDA 环境
/root/miniconda3/bin/python -c "import torch; print('torch=', torch.__version__); print('cuda=', torch.version.cuda)"

# 验证 ComfyUI 与应用目录存在
test -f /root/ComfyUI/main.py && echo "ComfyUI OK"
test -f /root/3lora-ltx23-app/start-services.sh && echo "APP OK"

# 可选：启动后验证接口
curl http://127.0.0.1:6008/api/health
```

## 补充说明

- 镜像中的主应用目录为 `/root/3lora-ltx23-app`。
- ComfyUI 运行目录为 `/root/ComfyUI`。
- 前端与后端合并服务默认监听 `6008` 端口。
- ComfyUI 默认监听 `127.0.0.1:6006`。
- 仓库中的 `zealman/...` 路径仅用于现有模型仓库命名空间，不是对外应用名称，不能直接改写为 `3lora`。
