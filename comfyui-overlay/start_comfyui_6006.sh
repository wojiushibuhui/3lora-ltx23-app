#!/usr/bin/env bash
cd /root/ComfyUI || exit 1
exec /root/miniconda3/bin/python main.py --listen 127.0.0.1 --port 6006 --enable-cors-header '*' --database-url sqlite:////root/ComfyUI/user/comfyui-6006.db
