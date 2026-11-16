"""PKMon 第三阶段验收脚本：图鉴/背包接口的真实 HTTP 验证。

流程：注册 → 登录 → 空图鉴/空背包 → 开始自习 → 连续上传合格位置样本 →
触发遭遇 → 取题 → 答对 → 图鉴与背包应出现 1 种 · 1 次 → 重放同一请求应幂等。

用法：python verify_collection.py http://127.0.0.1:4201
输出：控制台表格 + 同目录 verify-collection.json
"""
import json
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

BASE = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://127.0.0.1:4201"
REGION = "library_entrance"
LAT, LNG = 39.9042, 116.4074
RESULTS = []


def call(method, path, body=None, token=None, expect=200):
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8")
            status = resp.status
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8")
        status = exc.code
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        payload = {"raw": raw}
    return status, payload


def check(name, ok, detail=""):
    RESULTS.append({"检查项": name, "结果": "PASS" if ok else "FAIL", "说明": detail})
    print(f"[{'PASS' if ok else 'FAIL'}] {name}  {detail}")


def envelope_data(payload):
    return payload.get("data") if isinstance(payload, dict) else None


def main():
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    username = f"stage3_{stamp}"
    password = "Pkmon#Stage3-2026"

    st, body = call("POST", "/api/v1/auth/register",
                    {"username": username, "password": password, "nickname": "第三阶段验收"})
    check("注册新账号", st == 200 and envelope_data(body) is not None, f"HTTP {st}")

    st, body = call("POST", "/api/v1/auth/login", {"username": username, "password": password})
    login = envelope_data(body) or {}
    token = login.get("token")
    check("登录取得 Bearer 会话", bool(token), f"HTTP {st}")

    st, body = call("GET", "/api/v1/collection/dex", token=token)
    dex0 = envelope_data(body) or {}
    entries0 = dex0.get("entries") or []
    check("登录后图鉴返回全部目录条目",
          len(entries0) == 1 and entries0[0]["count"] == 0 and entries0[0]["firstCapturedAt"] is None,
          f"条目 {len(entries0)}，计数 {entries0[0]['count'] if entries0 else 'n/a'}，"
          f"已收 {dex0.get('collectedSpeciesCount')}/{dex0.get('totalSpeciesCount')}")

    st, body = call("GET", "/api/v1/collection/bag", token=token)
    bag0 = envelope_data(body) or {}
    check("登录后背包为空", bag0.get("totalCount") == 0 and not bag0.get("entries"),
          f"总数 {bag0.get('totalCount')}")

    st, body = call("POST", "/api/v1/study/tasks",
                    {"regionId": REGION, "requestId": str(uuid.uuid4()), "locationSource": "SIMULATED"},
                    token=token)
    task = envelope_data(body) or {}
    task_id = task.get("taskId")
    check("开始自习任务", bool(task_id),
          f"HTTP {st}，阈值 {task.get('requiredSeconds')} 秒，位置来源 {task.get('locationSource')}")

    spawn_id = None
    for i in range(14):
        now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        st, body = call("POST", f"/api/v1/study/tasks/{task_id}/samples",
                        {"sampleId": str(uuid.uuid4()), "latitude": LAT, "longitude": LNG,
                         "accuracyMeters": 8.0, "sampledAt": now,
                         "coordinateSystem": "GCJ02", "source": "SIMULATED"},
                        token=token)
        sample = envelope_data(body) or {}
        if sample.get("spawnId"):
            spawn_id = sample["spawnId"]
            print(f"      第 {i + 1} 条样本触发遭遇：有效 {sample.get('effectiveSeconds')} 秒，"
                  f"状态 {sample.get('status')}")
            break
        time.sleep(1.2)
    check("驻留达标后产生且只产生一个遭遇", bool(spawn_id), f"spawnId={spawn_id}")

    st, body = call("POST", "/api/v1/capture/challenge", {"spawnId": spawn_id}, token=token)
    challenge = envelope_data(body) or {}
    challenge_id = challenge.get("challengeId")
    options = [o["optionId"] for o in (challenge.get("options") or [])]
    check("取题返回挑战与选项且不含答案",
          bool(challenge_id) and options == ["A", "B", "C"] and "correctOptionId" not in challenge,
          f"选项 {options}")

    request_id = str(uuid.uuid4())
    st, body = call("POST", "/api/v1/capture/answer",
                    {"challengeId": challenge_id, "requestId": request_id, "optionId": "A"},
                    token=token)
    answer = envelope_data(body) or {}
    check("答对后收录成功", answer.get("result") == "CORRECT" and bool(answer.get("captureRecordId")),
          f"结果 {answer.get('result')}，收录号 {answer.get('captureRecordId')}")

    st, body = call("GET", "/api/v1/collection/dex", token=token)
    dex1 = envelope_data(body) or {}
    e1 = (dex1.get("entries") or [{}])[0]
    check("图鉴出现已解锁条目且带首次收录时刻",
          e1.get("count") == 1 and e1.get("firstCapturedAt") is not None
          and dex1.get("collectedSpeciesCount") == 1,
          f"{e1.get('name')} 计数 {e1.get('count')}，首次 {e1.get('firstCapturedAt')}")

    st, body = call("GET", "/api/v1/collection/bag", token=token)
    bag1 = envelope_data(body) or {}
    b1 = (bag1.get("entries") or [{}])[0]
    check("背包出现持有记录",
          bag1.get("totalCount") == 1 and bag1.get("speciesCount") == 1 and b1.get("name") == "攻城狮",
          f"总数 {bag1.get('totalCount')}，种类 {bag1.get('speciesCount')}")

    st, body = call("GET", "/api/v1/collection/summary", token=token)
    summary = envelope_data(body) or {}
    check("概览与图鉴/背包口径一致",
          summary.get("collectedSpeciesCount") == 1 and summary.get("captureCount") == 1,
          f"{summary.get('collectedSpeciesCount')}/{summary.get('totalSpeciesCount')} 种，"
          f"累计 {summary.get('captureCount')} 次")

    st, body = call("POST", "/api/v1/capture/answer",
                    {"challengeId": challenge_id, "requestId": request_id, "optionId": "A"},
                    token=token)
    replay = envelope_data(body) or {}
    st2, body2 = call("GET", "/api/v1/collection/dex", token=token)
    dex2 = envelope_data(body2) or {}
    e2 = (dex2.get("entries") or [{}])[0]
    check("重放同一请求不重复收录",
          e2.get("count") == 1 and replay.get("result") == "CORRECT",
          f"重放后计数 {e2.get('count')}")

    st, body = call("GET", "/api/v1/collection/dex")
    check("未登录访问图鉴被拒绝", st in (401, 403), f"HTTP {st}")

    passed = sum(1 for r in RESULTS if r["结果"] == "PASS")
    print(f"\n合计 {len(RESULTS)} 项，通过 {passed} 项，失败 {len(RESULTS) - passed} 项")
    out = {"base": BASE, "username": username, "generatedAt": datetime.now(timezone.utc).isoformat(),
           "checks": RESULTS}
    with open("verify-collection.json", "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2)
    print("结果已写入 verify-collection.json")
    return 0 if passed == len(RESULTS) else 1


if __name__ == "__main__":
    sys.exit(main())
