# 《大秦：2076》（玄黑沙盘）Godot 4 工程骨架 v2.1

> 参赛队伍：望秦社 · 2026 开源游戏开发大赛（OSGJ）· 主题「守·望」

## 快速开始

Windows 本机可直接双击 `run_game.cmd` 启动游戏。脚本自动查找 `D:\Tools\Godot` 或 PATH 中的 Godot，也支持用环境变量 `GODOT_EXE` 指定引擎路径；启动前会自动导入资源。

1. 使用 **Godot 4.2+** 打开本目录（选择 `project.godot`）。
2. 直接按 `F5` 运行主场景 `res://scenes/main.tscn`，即可进入 3D 玄黑沙盘可玩版。
3. 右上角可一键切换 **完整池（9名臣/12外挂/3隐藏关）** 与 **MVP 保底池（4名臣/8外挂/1隐藏关）**，并支持 **俯视沙盘 / 右看终端** 双机位 `create_tween()` 平滑切换。

## 运行 49 条核心逻辑验收测试

* **方式一（Godot 4 无头模式）：**
  ```bash
  godot --headless --path . -s res://tests/run_tests.gd
  ```
* **方式二（Python 镜像校验器，不依赖 Godot 环境）：**
  ```bash
  python3 tests/verify_logic.py
  ```

## 目录结构

* `data/game_data.json`：v2.1 数值、板块、名臣、外挂、突发事件与隐藏关定案配置
* `data/lines.json`：本地名臣互怼词库（每条 ≤ 25 字，运行时零联网）
* `scripts/core/game_core.gd`：纯逻辑核心层（不依赖场景树）
* `scripts/ui/main_scene.gd`：3D 沙盘壳子、青铜鼎火光、2D 全息立绘投影与 UI 防呆
* `shaders/hologram.gdshader`：全息扫描线与赛博青辉光着色器
* `docs/interface.md`：核心逻辑与 UI 信号契约
* `docs/AI_LOG.md`：AI 与素材合规登记日志
* `tests/cases.json`：49 条规则与边界验收用例
