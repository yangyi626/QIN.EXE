# 《大秦：2076》逻辑与表现分离接口文档（`docs/interface.md`）

> 架构铁律：`scripts/core/game_core.gd` 继承 `RefCounted`，不引用任何 `Node`、场景树或 UI 控件；`scripts/ui/` 仅调用 `GameCore` 公开方法并订阅信号，禁止反向篡改内部状态。

## 一、核心信号（UI 订阅）

| 信号名 | 参数 | 触发时机 |
| :--- | :--- | :--- |
| `state_changed(snapshot: Dictionary)` | 只读状态快照 | 任意状态变动后统一发射，供 UI 刷新显示 |
| `strike_performed(region_id: String, damage: int, source: String, conquered: bool)` | 板块 ID、伤害、来源、是否攻克 | 常规进攻、军事外挂、核聚变玉玺或韩信自动打击命中时 |
| `event_triggered(event_data: Dictionary)` | 事件字典 | 每 3 回合结算弹出二选一突发事件时 |
| `advisor_spoke(advisor_id: String, name: String, line: String)` | 名臣 ID、姓名、台词（≤25字） | 召唤名臣、回合开始或低民心提示隐藏关时 |
| `hidden_triggered(hidden_id: String, reward_text: String)` | 隐藏关 ID、奖励说明 | 玩家点击触发蓬莱仙岛、大泽乡暗流或南极时间舱时 |
| `game_ended(ending_code: String, ending_data: Dictionary)` | `win_sage` / `win_tyrant` / `lose_morale` / `lose_time` | 统一 6 板块瞬间、民心归零或 12 回合超时 |

## 二、公开命令方法（UI 调用）

* `init_game(game_data: Dictionary, lines_data: Dictionary, mvp_only: bool = false, rng_seed: int = -1) -> void`
* `get_snapshot() -> Dictionary`：返回 `turn`, `patience`, `morale`, `morale_cap`, `actions_left`, `attack_left`, `refreshes_left`, `conquered_count`, `act`, `conventional_power`, `sea_unlocked`, `regions`, `advisors`, `terminal_cards`, `hidden_visible`, `pending_event`, `game_over`
* `conventional_attack(region_id: String) -> Dictionary`（返回 `{"ok": bool, "error": String, ...}`）
* `buy_cheat(slot_index: int, target_region_id: String = "") -> Dictionary`
* `summon_advisor(slot_index: int, replace_index: int = -1) -> Dictionary`
* `refresh_terminal() -> Dictionary`
* `build_fleet() -> Dictionary`
* `trigger_hidden(hidden_id: String) -> Dictionary`
* `end_turn() -> Dictionary`
* `resolve_event(choice: String) -> Dictionary`（`"A"` 或 `"B"`）

## 三、确定性测试辅助（仅 `tests/` 调用）

* `set_terminal_cards_for_test(cards: Array) -> void`
* `force_morale_for_test(value: int) -> void`
* `force_region_conquered_for_test(region_id: String) -> void`
