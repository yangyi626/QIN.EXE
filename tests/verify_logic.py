#!/usr/bin/env python3
"""
生成 49 条验收用例 tests/cases.json 并用镜像逻辑引擎全量校验 game_data.json / lines.json / cases.json
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = json.load(open(os.path.join(ROOT, "data/game_data.json"), encoding="utf-8"))
LINES = json.load(open(os.path.join(ROOT, "data/lines.json"), encoding="utf-8"))


def build_49_cases():
    return [
        # 1-5: 初始状态与总战力校验
        {"id": "T01", "name": "初始民心60/耐心12/行动2/进攻1/刷新3", "steps": [], "expect": {"morale": 60, "patience": 12, "actions_left": 2, "attack_left": 1, "refreshes_left": 3}},
        {"id": "T02", "name": "常规进攻草原(1.00)一击拿下15血且不占行动", "steps": [{"op": "attack", "target": "steppe"}], "expect": {"last_ok": True, "actions_left": 2, "attack_left": 0, "region_hp": {"steppe": 0}, "conquered_count": 1}},
        {"id": "T03", "name": "常规进攻西域(1.00)剩10血", "steps": [{"op": "attack", "target": "west"}], "expect": {"last_ok": True, "region_hp": {"west": 10}}},
        {"id": "T04", "name": "未克西域不可常规进攻南亚", "steps": [{"op": "attack", "target": "south_asia"}], "expect": {"last_ok": False, "attack_left": 1}},
        {"id": "T05", "name": "未克西域不可常规进攻西亚北非", "steps": [{"op": "attack", "target": "west_asia"}], "expect": {"last_ok": False}},
        # 6-10: 前置路线与效率折扣
        {"id": "T06", "name": "已克西域可常规进攻南亚(0.75=>15伤)", "setup": {"conquered": ["west"]}, "steps": [{"op": "attack", "target": "south_asia"}], "expect": {"last_ok": True, "region_hp": {"south_asia": 37}}},
        {"id": "T07", "name": "已克西域可常规进攻西亚北非(0.60=>12伤)", "setup": {"conquered": ["west"]}, "steps": [{"op": "attack", "target": "west_asia"}], "expect": {"last_ok": True, "region_hp": {"west_asia": 70}}},
        {"id": "T08", "name": "未克西亚不可常规进攻欧罗巴", "setup": {"conquered": ["west"]}, "steps": [{"op": "attack", "target": "europe"}], "expect": {"last_ok": False}},
        {"id": "T09", "name": "已克西亚可常规进攻欧罗巴(0.30=>6伤)", "setup": {"conquered": ["west", "west_asia"]}, "steps": [{"op": "attack", "target": "europe"}], "expect": {"last_ok": True, "region_hp": {"europe": 129}}},
        {"id": "T10", "name": "未渡海不可常规进攻新大陆", "steps": [{"op": "attack", "target": "americas"}], "expect": {"last_ok": False}},
        # 11-15: 行动点、刷新与开局免费钩子
        {"id": "T11", "name": "同回合不可常规进攻两次", "steps": [{"op": "attack", "target": "steppe"}, {"op": "attack", "target": "west"}], "expect": {"last_ok": False, "region_hp": {"west": 30}}},
        {"id": "T12", "name": "刷新不占行动且每次-5民心", "steps": [{"op": "refresh"}], "expect": {"last_ok": True, "morale": 55, "actions_left": 2, "refreshes_left": 2}},
        {"id": "T13", "name": "每回合最多刷新3次，第4次拒绝", "steps": [{"op": "refresh"}, {"op": "refresh"}, {"op": "refresh"}, {"op": "refresh"}], "expect": {"last_ok": False, "morale": 45, "refreshes_left": 0}},
        {"id": "T14", "name": "首回合无人机蜂群免费（0民心）并打45伤", "setup": {"cards": [{"kind": "cheat", "id": "drone"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"last_ok": True, "morale": 60, "actions_left": 1, "region_hp": {"europe": 90}}},
        {"id": "T15", "name": "首回合首次召唤名臣免费（0民心）", "setup": {"cards": [{"kind": "advisor", "id": "zhugeliang"}]}, "steps": [{"op": "summon", "slot": 0}], "expect": {"last_ok": True, "morale": 60, "actions_left": 1}},
        # 16-20: 民生外挂与防呆
        {"id": "T16", "name": "杂交水稻+30民心且不超过100上限", "setup": {"morale": 80, "cards": [{"kind": "cheat", "id": "rice"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"last_ok": True, "morale": 100}},
        {"id": "T17", "name": "青霉素+20民心并使当回合南亚常规效率恢复1.00", "setup": {"conquered": ["west"], "cards": [{"kind": "cheat", "id": "penicillin"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "attack", "target": "south_asia"}], "expect": {"last_ok": True, "morale": 80, "region_hp": {"south_asia": 32}}},
        {"id": "T18", "name": "水泥直道+15民心且永久常规战力+10", "setup": {"cards": [{"kind": "cheat", "id": "cement_road"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"last_ok": True, "morale": 75, "conventional_power": 30}},
        {"id": "T19", "name": "义务教育须在常规进攻前买，进攻后拒绝", "setup": {"cards": [{"kind": "cheat", "id": "education"}]}, "steps": [{"op": "attack", "target": "steppe"}, {"op": "buy", "slot": 0}], "expect": {"last_ok": False, "morale": 60}},
        {"id": "T20", "name": "购买义务教育后本回合禁止常规进攻", "setup": {"cards": [{"kind": "cheat", "id": "education"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "attack", "target": "steppe"}], "expect": {"last_ok": False, "morale": 85}},
        # 21-26: 军事外挂与渡海
        {"id": "T21", "name": "卫星制导重炮无视前置打欧罗巴75伤(-30民心)", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "artillery"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"last_ok": True, "morale": 30, "region_hp": {"europe": 60}}},
        {"id": "T22", "name": "AK-47兵马俑永久+30常规战力(-25民心)", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "ak47"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"last_ok": True, "morale": 35, "conventional_power": 50}},
        {"id": "T23", "name": "跨海铁甲舰解锁渡海并对新大陆造成30伤", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "ironclad"}]}, "steps": [{"op": "buy", "slot": 0, "target": "americas"}], "expect": {"last_ok": True, "morale": 45, "sea_unlocked": True, "region_hp": {"americas": 15}}},
        {"id": "T24", "name": "强征造楼船-30民心占1行动并解锁渡海", "steps": [{"op": "fleet"}], "expect": {"last_ok": True, "morale": 30, "actions_left": 1, "sea_unlocked": True}},
        {"id": "T25", "name": "每回合仅2次行动，第3次买牌被拒", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "rice"}, {"kind": "cheat", "id": "penicillin"}, {"kind": "cheat", "id": "cement_road"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "buy", "slot": 1}, {"op": "buy", "slot": 2}], "expect": {"last_ok": False, "actions_left": 0}},
        {"id": "T26", "name": "核聚变传国玉玺-50民心秒杀欧罗巴", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "nuke_seal"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"last_ok": True, "morale": 10, "region_hp": {"europe": 0}}},
        # 27-31: 黑科技与结算顺序
        {"id": "T27", "name": "全息假始皇-15民心且耐心+3", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "holo_emperor"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"last_ok": True, "morale": 45, "patience": 15}},
        {"id": "T28", "name": "赛博焚书锁死2回合民心扣减，第2回合末反噬-35", "setup": {"free_hook": False, "cards": [{"kind": "cheat", "id": "cyber_burn"}, {"kind": "cheat", "id": "nuke_seal"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "buy", "slot": 1, "target": "europe"}, {"op": "end_turn"}, {"op": "end_turn"}], "expect": {"morale": 25}},
        {"id": "T29", "name": "跨时空贷款立刻+40，下回合扣15", "setup": {"morale": 50, "cards": [{"kind": "cheat", "id": "time_loan"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "end_turn"}], "expect": {"morale": 75}},
        {"id": "T30", "name": "攻克西域后回合开始自动+5丝路红利", "setup": {"conquered": ["west"]}, "steps": [{"op": "end_turn"}], "expect": {"morale": 65, "patience": 11}},
        {"id": "T31", "name": "丝路+5与贷款-15同回合结算净-10", "setup": {"morale": 50, "conquered": ["west"], "cards": [{"kind": "cheat", "id": "time_loan"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "end_turn"}], "expect": {"morale": 80}},
        # 32-41: 9 位名臣全部技能与联动校验
        {"id": "T32", "name": "诸葛亮使跨海铁甲舰15民心向上取整为8", "setup": {"free_hook": False, "advisors": ["zhugeliang"], "cards": [{"kind": "cheat", "id": "ironclad"}]}, "steps": [{"op": "buy", "slot": 0, "target": "americas"}], "expect": {"morale": 52}},
        {"id": "T33", "name": "诸葛亮+王安石同场，卫星重炮30*0.5*0.8=12", "setup": {"free_hook": False, "advisors": ["zhugeliang", "wanganshi"], "cards": [{"kind": "cheat", "id": "artillery"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"morale": 48}},
        {"id": "T34", "name": "曹操使卫星重炮伤害翻倍至150且额外-10民心", "setup": {"free_hook": False, "advisors": ["caocao"], "cards": [{"kind": "cheat", "id": "artillery"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"morale": 20, "region_hp": {"europe": 0}}},
        {"id": "T35", "name": "曹操+AK47正式生效：常规战力+60（总80）且额外-10民心", "setup": {"free_hook": False, "advisors": ["caocao"], "cards": [{"kind": "cheat", "id": "ak47"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"morale": 25, "conventional_power": 80}},
        {"id": "T36", "name": "汤和使造楼船消耗减半至15", "setup": {"advisors": ["tanghe"]}, "steps": [{"op": "fleet"}], "expect": {"morale": 45, "sea_unlocked": True}},
        {"id": "T37", "name": "汤和不减半跨时空贷款扣息(-15)", "setup": {"morale": 50, "advisors": ["tanghe"], "cards": [{"kind": "cheat", "id": "time_loan"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "end_turn"}], "expect": {"morale": 75}},
        {"id": "T38", "name": "商鞅使常规战力翻倍(40)且民心上限锁80", "setup": {"morale": 90, "advisors": ["shangyang"], "cards": [{"kind": "cheat", "id": "rice"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"morale": 80, "morale_cap": 80, "conventional_power": 40}},
        {"id": "T39", "name": "霍去病使无人机蜂群秒杀135血欧罗巴", "setup": {"free_hook": False, "advisors": ["huoqubing"], "cards": [{"kind": "cheat", "id": "drone"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"morale": 40, "region_hp": {"europe": 0}}},
        {"id": "T40", "name": "张骞在场攻克草原立刻+8民心", "setup": {"advisors": ["zhangqian"]}, "steps": [{"op": "attack", "target": "steppe"}], "expect": {"morale": 68}},
        {"id": "T41", "name": "李冰使杂交水稻翻倍+60，但不翻倍跨时空贷款", "setup": {"morale": 10, "advisors": ["libing"], "cards": [{"kind": "cheat", "id": "rice"}, {"kind": "cheat", "id": "time_loan"}]}, "steps": [{"op": "buy", "slot": 0}], "expect": {"morale": 70}},
        {"id": "T42", "name": "王安石使终端刷新免费(0民心)", "setup": {"advisors": ["wanganshi"]}, "steps": [{"op": "refresh"}], "expect": {"morale": 60, "refreshes_left": 2}},
        # 43-46: 三大隐藏关精确门槛校验
        {"id": "T43", "name": "民心<50显现蓬莱仙岛，触发+35民心且耐心-1", "setup": {"morale": 45}, "steps": [{"op": "hidden", "id": "penglai"}], "expect": {"last_ok": True, "morale": 80, "patience": 11, "actions_left": 1}},
        {"id": "T44", "name": "民心<40显现大泽乡暗流，无名臣时不可触发", "setup": {"morale": 35}, "steps": [{"op": "hidden", "id": "dazexiang"}], "expect": {"last_ok": False, "hidden_visible": {"dazexiang": True}}},
        {"id": "T45", "name": "大泽乡暗流有名臣时+25民心，且火星在回血后仍保留至点击", "setup": {"morale": 35, "advisors": ["tanghe"], "cards": [{"kind": "cheat", "id": "rice"}]}, "steps": [{"op": "buy", "slot": 0}, {"op": "hidden", "id": "dazexiang"}], "expect": {"last_ok": True, "morale": 90}},
        {"id": "T46", "name": "南极时间舱消耗1次刷新不占行动且+50民心", "setup": {"morale": 40}, "steps": [{"op": "hidden", "id": "antarctica"}], "expect": {"last_ok": True, "morale": 90, "actions_left": 2, "refreshes_left": 2}},
        # 47-49: 三大结局与幕次切换校验
        {"id": "T47", "name": "统一第6板块且民心>=60立即判win_sage", "setup": {"morale": 65, "conquered": ["west", "south_asia", "west_asia", "europe", "americas"]}, "steps": [{"op": "attack", "target": "steppe"}], "expect": {"conquered_count": 6, "game_over_code": "win_sage"}},
        {"id": "T48", "name": "统一第6板块且民心<60立即判win_tyrant", "setup": {"morale": 45, "conquered": ["west", "south_asia", "west_asia", "europe", "americas"]}, "steps": [{"op": "attack", "target": "steppe"}], "expect": {"conquered_count": 6, "game_over_code": "win_tyrant"}},
        {"id": "T49", "name": "民心归零立即判lose_morale，占领4块切入第3幕", "setup": {"morale": 20, "free_hook": False, "conquered": ["steppe", "west", "south_asia", "west_asia"], "cards": [{"kind": "cheat", "id": "artillery"}]}, "steps": [{"op": "buy", "slot": 0, "target": "europe"}], "expect": {"morale": 0, "act": 3, "game_over_code": "lose_morale"}},
    ]


class PyGameCoreMirror:
    def __init__(self, data, mvp_only=False):
        self.data = data
        self.mvp_only = mvp_only
        self.turn = 1
        self.patience = 12
        self.morale = 60
        self.actions_left = 2
        self.attack_left = 1
        self.refreshes_left = 3
        self.free_hook_available = True
        self.regions = [dict(r, max_hp=r["hp"], conquered=False) for r in data["regions"]]
        self.advisors = []
        self.terminal_cards = []
        self.bought_one_time = set()
        self.sea_unlocked = False
        self.cement_road_bonus = 0
        self.ak47_bonus = 0
        self.penicillin_turn = False
        self.education_turn = False
        self.overheat_no_refresh = False
        self.overheat_power_debuff = 0
        self.cyber_burn_turns = 0
        self.loan_queue = []
        self.hidden = {k: {"found": False, "used": False} for k in ["penglai", "dazexiang", "antarctica"]}
        self.game_over_code = ""

    def has_adv(self, aid): return any(a["id"] == aid for a in self.advisors)
    def cap(self): return 80 if self.has_adv("shangyang") else 100
    def conquered_count(self): return sum(1 for r in self.regions if r["conquered"])
    def act(self):
        c = self.conquered_count()
        return 1 if c <= 1 else (2 if c <= 3 else 3)
    def conv_power(self):
        b = 20 + self.cement_road_bonus + self.ak47_bonus - self.overheat_power_debuff
        if self.has_adv("shangyang"): b *= 2
        return max(0, b)
    def find_r(self, rid): return next((r for r in self.regions if r["id"] == rid), None)
    def can_attack(self, rid):
        r = self.find_r(rid)
        if not r or r["conquered"]: return False
        if r["requires_sea"]: return self.sea_unlocked
        if not r["prereq"]: return True
        p = self.find_r(r["prereq"])
        return bool(p and p["conquered"])
    def hidden_vis(self, hid):
        if self.hidden[hid]["used"]: return False
        if hid == "dazexiang": return self.hidden[hid]["found"]
        return (not self.mvp_only) and self.morale < 50
    def mod_morale(self, d, ignore_lock=False):
        if d < 0 and self.cyber_burn_turns > 0 and not ignore_lock: return
        self.morale = max(0, min(self.cap(), self.morale + d))
        if self.morale < 40: self.hidden["dazexiang"]["found"] = True
        if self.morale < 50 and not self.mvp_only:
            self.hidden["penglai"]["found"] = True
            self.hidden["antarctica"]["found"] = True
        if self.morale <= 0 and not self.game_over_code:
            self.game_over_code = "lose_morale"
    def dmg_r(self, rid, raw, instant=False):
        r = self.find_r(rid)
        if not r or r["conquered"]: return False
        dmg = r["hp"] if instant else max(0, raw)
        r["hp"] = max(0, r["hp"] - dmg)
        if r["hp"] == 0:
            r["conquered"] = True
            if self.has_adv("zhangqian"): self.mod_morale(8)
            if self.conquered_count() >= 6:
                self.game_over_code = "win_sage" if self.morale >= 60 else "win_tyrant"
        return True
    def step(self, s):
        op = s["op"]
        if op == "attack":
            if self.game_over_code or self.attack_left <= 0 or self.education_turn or not self.can_attack(s["target"]): return False
            r = self.find_r(s["target"])
            eff = 1.0 if (r["id"] == "south_asia" and self.penicillin_turn) else r["efficiency"]
            self.attack_left = 0
            return self.dmg_r(r["id"], int(math.floor(self.conv_power() * eff)))
        if op == "refresh":
            if self.game_over_code or self.overheat_no_refresh or self.refreshes_left <= 0: return False
            self.refreshes_left -= 1
            cost = 0 if self.has_adv("wanganshi") else 5
            if cost: self.mod_morale(-cost)
            return True
        if op == "fleet":
            if self.game_over_code or self.sea_unlocked or self.actions_left <= 0: return False
            self.actions_left -= 1; self.sea_unlocked = True
            self.mod_morale(-(15 if self.has_adv("tanghe") else 30))
            return True
        if op == "summon":
            if self.game_over_code or self.actions_left <= 0: return False
            c = self.terminal_cards[s["slot"]]
            if c["bought"] or c["kind"] != "advisor": return False
            cost = 0 if (self.turn == 1 and self.free_hook_available) else c["data"]["cost"]
            if self.turn == 1 and self.free_hook_available: self.free_hook_available = False
            self.actions_left -= 1; c["bought"] = True
            if cost: self.mod_morale(-cost)
            if not self.game_over_code:
                self.advisors.append(c["data"])
                if c["data"]["id"] == "shangyang" and self.morale > 80: self.morale = 80
            return True
        if op == "buy":
            if self.game_over_code or self.actions_left <= 0: return False
            c = self.terminal_cards[s["slot"]]
            if c["bought"] or c["kind"] != "cheat": return False
            ch = c["data"]
            if ch["id"] == "education" and self.attack_left <= 0: return False
            d = ch["morale_delta"]
            if d >= 0:
                eff = d * 2 if (ch["category"] == "livelihood" and self.has_adv("libing")) else d
            elif self.turn == 1 and self.free_hook_available and ch["id"] == "drone":
                eff = 0
                self.free_hook_available = False
            else:
                mult = (0.5 if (ch["category"] == "military" and self.has_adv("zhugeliang")) else 1.0) * (0.8 if self.has_adv("wanganshi") else 1.0)
                cost = math.ceil(abs(d) * mult) + (10 if (ch["category"] == "military" and self.has_adv("caocao")) else 0)
                eff = -cost
            self.actions_left -= 1; c["bought"] = True
            if eff: self.mod_morale(eff)
            if self.game_over_code: return True
            cm = 2 if (ch["category"] == "military" and self.has_adv("caocao")) else 1
            cid = ch["id"]
            if cid == "penicillin": self.penicillin_turn = True
            elif cid == "cement_road": self.cement_road_bonus += 10
            elif cid == "education": self.education_turn = True
            elif cid == "drone": self.dmg_r(s["target"], ch["damage"] * cm, self.has_adv("huoqubing"))
            elif cid == "artillery": self.dmg_r(s["target"], ch["damage"] * cm)
            elif cid == "ak47": self.ak47_bonus += 30 * cm
            elif cid == "ironclad": self.sea_unlocked = True; self.dmg_r(s["target"], ch["damage"] * cm)
            elif cid == "cyber_burn": self.cyber_burn_turns = 2
            elif cid == "holo_emperor": self.patience += 3
            elif cid == "time_loan": self.loan_queue.extend([15, 15, 15])
            elif cid == "nuke_seal": self.dmg_r(s["target"], 999, True)
            return True
        if op == "hidden":
            hid = s["id"]
            if not self.hidden_vis(hid): return False
            if hid == "penglai":
                if self.actions_left <= 0: return False
                self.actions_left -= 1; self.hidden[hid]["used"] = True
                self.patience = max(1, self.patience - 1); self.mod_morale(35)
                return True
            if hid == "dazexiang":
                if self.actions_left <= 0 or not self.advisors: return False
                self.actions_left -= 1; self.hidden[hid]["used"] = True; self.mod_morale(25)
                return True
            if hid == "antarctica":
                if self.refreshes_left <= 0: return False
                self.refreshes_left -= 1; self.hidden[hid]["used"] = True; self.mod_morale(50)
                return True
        if op == "end_turn":
            if self.cyber_burn_turns > 0:
                self.cyber_burn_turns -= 1
                if self.cyber_burn_turns == 0:
                    self.mod_morale(-35, True)
                    if self.game_over_code: return True
            self.turn += 1; self.patience -= 1
            if self.patience <= 0: self.game_over_code = "lose_time"; return True
            self.actions_left = 2; self.attack_left = 1; self.refreshes_left = 3
            self.penicillin_turn = False; self.education_turn = False; self.free_hook_available = False
            if self.find_r("west")["conquered"]: self.mod_morale(5)
            if self.loan_queue: self.mod_morale(-self.loan_queue.pop(0))
            return True
        return False


def main():
    # 1. Write tests/cases.json (49 cases)
    cases = build_49_cases()
    assert len(cases) == 49, f"Expected 49 cases, got {len(cases)}"
    cases_path = os.path.join(ROOT, "tests/cases.json")
    with open(cases_path, "w", encoding="utf-8") as f:
        json.dump(cases, f, ensure_ascii=False, indent=2)

    # 2. Verify data/game_data.json totals
    total_hp = sum(r["hp"] for r in DATA["regions"])
    assert total_hp == 359, f"Total region HP should be 359, got {total_hp}"
    assert len(DATA["advisors"]) == 18 and len(DATA["cheats"]) == 12 and len(DATA["events"]) == 4

    # 3. Verify data/lines.json max length <= 25 chars
    over = []
    for aid, d in LINES["advisors"].items():
        for k, v in d.items():
            for line in (v if isinstance(v, list) else [v]):
                if len(line) > 25:
                    over.append((aid, k, len(line), line))
    assert not over, f"Lines over 25 chars: {over}"

    # 4. Run all 49 cases
    passed = 0
    for tc in cases:
        core = PyGameCoreMirror(DATA, tc.get("mvp_only", False))
        st = tc.get("setup", {})
        if "advisors" in st:
            for aid in st["advisors"]:
                core.advisors.append(next(a for a in DATA["advisors"] if a["id"] == aid))
        if "morale" in st:
            core.morale = min(core.cap(), st["morale"])
            if core.morale < 40: core.hidden["dazexiang"]["found"] = True
            if core.morale < 50: core.hidden["penglai"]["found"] = True; core.hidden["antarctica"]["found"] = True
        for rid in st.get("conquered", []):
            r = core.find_r(rid); r["hp"] = 0; r["conquered"] = True
        if "cards" in st:
            for cs in st["cards"]:
                src = DATA["advisors"] if cs["kind"] == "advisor" else DATA["cheats"]
                core.terminal_cards.append({"kind": cs["kind"], "bought": False, "data": next(x for x in src if x["id"] == cs["id"])})
        if "free_hook" in st: core.free_hook_available = st["free_hook"]
        last_ok = True
        for s in tc["steps"]: last_ok = core.step(s)
        exp = tc["expect"]
        if "last_ok" in exp: assert last_ok == exp["last_ok"], f"{tc['id']} last_ok mismatch"
        if "morale" in exp: assert core.morale == exp["morale"], f"{tc['id']} morale {core.morale} != {exp['morale']}"
        if "morale_cap" in exp: assert core.cap() == exp["morale_cap"], f"{tc['id']} cap mismatch"
        if "patience" in exp: assert core.patience == exp["patience"], f"{tc['id']} patience mismatch"
        if "actions_left" in exp: assert core.actions_left == exp["actions_left"], f"{tc['id']} actions mismatch"
        if "attack_left" in exp: assert core.attack_left == exp["attack_left"], f"{tc['id']} attack mismatch"
        if "refreshes_left" in exp: assert core.refreshes_left == exp["refreshes_left"], f"{tc['id']} refresh mismatch"
        if "conventional_power" in exp: assert core.conv_power() == exp["conventional_power"], f"{tc['id']} power mismatch"
        if "conquered_count" in exp: assert core.conquered_count() == exp["conquered_count"], f"{tc['id']} conquered mismatch"
        if "act" in exp: assert core.act() == exp["act"], f"{tc['id']} act mismatch"
        if "sea_unlocked" in exp: assert core.sea_unlocked == exp["sea_unlocked"], f"{tc['id']} sea mismatch"
        if "game_over_code" in exp: assert core.game_over_code == exp["game_over_code"], f"{tc['id']} ending mismatch"
        for rid, hp in exp.get("region_hp", {}).items():
            assert core.find_r(rid)["hp"] == hp, f"{tc['id']} {rid} hp {core.find_r(rid)['hp']} != {hp}"
        for hid, vis in exp.get("hidden_visible", {}).items():
            assert core.hidden_vis(hid) == vis, f"{tc['id']} hidden {hid} mismatch"
        passed += 1

    # 4. Extended v3.5 checks: 18 advisors (9M + 9F), portraits on disk, 4 dialogue buckets, 14 synergies, Boss Phase-2 & Paradox Core
    female_ids = ["baqing", "fuhao", "huangdaopo", "mulan", "wuzetian", "liqingzhao", "caiwenji", "fanlihua", "banzhao"]
    adv_map = {a["id"]: a for a in DATA["advisors"]}
    for fid in female_ids:
        assert fid in adv_map, f"Missing female advisor in game_data.json: {fid}"
        assert fid in LINES["advisors"], f"Missing female advisor in lines.json: {fid}"
        for bkt in ("summon", "normal", "low_morale", "hidden_hint"):
            assert LINES["advisors"][fid].get(bkt), f"Missing line bucket {fid}.{bkt}"
    for aid, adv in adv_map.items():
        rel_p = adv["portrait"].replace("res://", "")
        assert os.path.exists(os.path.join(ROOT, rel_p)), f"Missing portrait asset: {rel_p}"

    core_src = open(os.path.join(ROOT, "scripts", "core", "game_core.gd"), encoding="utf-8").read()
    for syn_id in [
        "wolong_jianxiong", "bianfa_shuangbi", "silu_shuili", "bingxian_guanjun", "wanjia_denghuo",
        "silu_danshang", "wushuang_zhanshen", "yishi_shouwang", "juedai_shuangjiao",
        "qiankun_xinzheng", "jinxiu_wenmai", "hujia_guihan", "jinguo_bingxian", "qianqiu_lantai",
    ]:
        assert f'"{syn_id}"' in core_src, f"Missing synergy in game_core.gd: {syn_id}"
    for hook in [
        "signal boss_phase_triggered", "signal paradox_awakened",
        "boss_lock_hp", "paradox_core", "_trigger_boss_phase2", "_awaken_paradox_boss",
    ]:
        assert hook in core_src, f"Missing boss/paradox hook in game_core.gd: {hook}"

    print(f"ALL CHECKS PASSED: {passed}/49 core cases + 18-advisor/14-synergy/boss-paradox checks, total_hp={total_hp}, all lines <= 25 chars.")


if __name__ == "__main__":
    main()
