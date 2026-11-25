# AI 与第三方素材使用声明日志（`docs/AI_LOG.md`）

> 依据 [2026 开源游戏开发大赛（OSGJ）](https://2026gamejam.osgame.org/) 合规要求，所有 AI 生成代码、文案与图像资产在此实时登记。

| 日期 | 工具/模型 | 用途分类 | 涉及文件路径 | 人工审核与修改说明 |
| :--- | :--- | :--- | :--- | :--- |
| 2026-11-22 | Gemini | 工程代码骨架 | `scripts/core/game_core.gd`, `scripts/ui/main_scene.gd`, `shaders/hologram.gdshader` | 严格依据团队策划案 v2.1 与接口规范生成，待团队在 Godot 4 中实机复核 |
| 2026-11-22 | Gemini | 配置与词库 | `data/game_data.json`, `data/lines.json`, `tests/cases.json` | 全部名臣台词均 ≤25 字，入库前须由团队成员逐条完成内容合规审核 |
| 2026-11-22 | 图像生成工具 | MVP 名臣立绘 | `assets/portraits/{zhugeliang,caocao,tanghe,huoqubing}.jpg` | 4 张 MVP 全息立绘（360×360），后续需向组委会确认 AI 图像是否计入第三方素材占比 |
| 2026-11-22 | 图像生成工具 | Sprint 名臣立绘 | `assets/portraits/{shangyang,zhangqian,libing,hanxin,wanganshi}.jpg` | 5 张扩展名臣全息立绘（360×360），至此 9 位名臣立绘全部齐备 |
| 2026-11-22 | 图像生成工具 | 场景概念与沙盘贴图 | `assets/textures/sandtable_map.jpg`, `assets/textures/concept_xianyang.jpg` | 咸阳宫概念图与 16:9 玄黑青铜世界地图顶视贴图（1280×720），已接入 3D 沙盘桌面 |
| 2026-11-25 | Codex | 沙盘交互、军令卡与战斗反馈 | `scripts/ui/main_scene.gd`, `shaders/territory_map.gdshader` | 使用已有地图与名臣素材，在 Godot 实机验证选区、瞄准、取消和攻克反馈。 |
| 2026-11-25 | Gemini + Python 程序合成 | 在场名臣槽位、弹窗视觉、3D 氛围与原创音效 | `scripts/ui/main_scene.gd`, `assets/audio/*.wav` | 补齐 2 位在场名臣状态栏与满员替换弹窗、统一暗青金事件/结局弹窗、合成 8 条零版权依赖的 PCM WAV 音效 |
| 2026-11-25 | Gemini | 邪恶冥刻风暗黑立体桌面重制 | `scenes/main.tscn`, `shaders/vignette.gdshader`, `shaders/hologram.gdshader`, `scripts/ui/main_scene.gd` | 重构透视鼠标视差相机、咸阳宫大殿远景、极简悬浮 HUD、名臣全息对白气泡、地图就地进攻弹窗、动态瞄准弧线与全类型 3D 打击/民生演出 |
