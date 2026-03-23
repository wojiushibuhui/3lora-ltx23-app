# 3lora 的 LTX2.3

用于将 AutoDL 上整理好的 LTX2.3 图文生视频环境发布为 AI 广场应用的仓库快照。

## 目录说明

- `comfyui-overlay/`: 需要覆盖到 `/root/ComfyUI` 的定制文件。
- `comfyui-workflows/`、`workflows/`: 预置工作流与相关资源。
- `modellink/`: 模型下载命令页和软链接管理页。
- `public/`、`dist/`: 前端静态资源与构建产物。
- `scripts/`: AutoDL 启动、守护、校验、打包脚本。

## 部署约定

- 应用目录默认使用 `/root/3lora-ltx23-app`。
- ComfyUI 运行目录默认使用 `/root/ComfyUI`。
- 多数脚本支持通过 `APP_DIR` 覆盖默认应用目录。

## 命名说明

- 对外展示名称已统一调整为 `3lora` / `3lora 的 LTX2.3`。
- `modellink`、工作流或配置中保留的 `zealman/...` 路径属于现有模型仓库命名空间，不能直接改名，否则会导致下载或加载失败。
