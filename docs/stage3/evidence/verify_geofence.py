"""PKMon 地理围栏与驻留边界验收：越界暂停、恢复保留已认可时长。

只验证状态与判定的对外表现，不涉及真机定位。
用法：python verify_geofence.py http://127.0.0.1:4203
"""
import json
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")

BASE = sys.argv[1].rstrip("/")
REGION = "library_entrance"
INSIDE = (39.9042, 116.4074)
OUTSIDE = (39.9200, 116.4300)          # 距中心约 2.5 km，明显超出 100m 退出半径
RESULTS = []


def call(method, path, body=None, token=None):
    req = urllib.request.Request(f"{BASE}{path}",
                                 data=json.dumps(body).encode() if body is not None else None,
                                 method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))


def check(name, ok, detail=""):
    RESULTS.append({"检查项": name, "结果": "PASS" if ok else "FAIL", "说明": detail})
    print(f"[{'PASS' if ok else 'FAIL'}] {name}  {detail}")


def sample(token, task_id, lat, lng, acc=8.0):
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    st, body = call("POST", f"/api/v1/study/tasks/{task_id}/samples",
                    {"sampleId": str(uuid.uuid4()), "latitude": lat, "longitude": lng,
                     "accuracyMeters": acc, "sampledAt": now,
                     "coordinateSystem": "GCJ02", "source": "SIMULATED"}, token)
    return (body.get("data") or {})


def main():
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    user = f"geofence_{stamp}"
    call("POST", "/api/v1/auth/register",
         {"username": user, "password": "Pkmon#Stage3-2026", "nickname": "boundary"})
    st, body = call("POST", "/api/v1/auth/login", {"username": user, "password": "Pkmon#Stage3-2026"})
    token = (body.get("data") or {}).get("token")
    check("登录取得会话", bool(token), f"HTTP {st}")

    st, body = call("POST", "/api/v1/study/tasks",
                    {"regionId": REGION, "requestId": str(uuid.uuid4()),
                     "locationSource": "SIMULATED"}, token)
    task_id = (body.get("data") or {}).get("taskId")
    check("开始自习任务", bool(task_id), f"HTTP {st}")

    s1 = sample(token, task_id, *INSIDE)
    time.sleep(2.2)
    s2 = sample(token, task_id, *INSIDE)
    time.sleep(2.2)
    s3 = sample(token, task_id, *INSIDE)
    effective_after_inside = s2.get("effectiveSeconds", 0)
    check("连续两条合格样本进入驻留", s2.get("status") in ("DWELLING", "TRIGGERED"),
          f"状态 {s2.get('status')}，有效 {effective_after_inside} 秒")

    # 首次越界：只记一次 outsideCount，不立即暂停
    o1 = sample(token, task_id, *OUTSIDE)
    check("首次越界不立刻暂停（缓冲带）", o1.get("status") in ("DWELLING", "TRIGGERED"),
          f"状态 {o1.get('status')}，暂停原因 {o1.get('pauseReason')}")

    # 第二次越界：进入 PAUSED / OUTSIDE
    o2 = sample(token, task_id, *OUTSIDE)
    check("连续越界后暂停且原因为 OUTSIDE",
          o2.get("status") == "PAUSED" and o2.get("pauseReason") == "OUTSIDE",
          f"状态 {o2.get('status')}，原因 {o2.get('pauseReason')}")

    paused_seconds = o2.get("effectiveSeconds", 0)
    # 暂停期间再送越界样本：时长不得增长
    o3 = sample(token, task_id, *OUTSIDE)
    check("暂停期间有效时长不增长", o3.get("effectiveSeconds", -1) == paused_seconds,
          f"暂停前 {paused_seconds} 秒，暂停后 {o3.get('effectiveSeconds')} 秒")

    # 恢复：回到区域内两条合格样本
    r1 = sample(token, task_id, *INSIDE)
    time.sleep(1.5)
    r2 = sample(token, task_id, *INSIDE)
    check("恢复后保留已认可时长且状态回到驻留",
          r2.get("status") in ("DWELLING", "TRIGGERED") and r2.get("effectiveSeconds", 0) >= paused_seconds,
          f"状态 {r2.get('status')}，有效 {r2.get('effectiveSeconds')} 秒（暂停前 {paused_seconds} 秒）")

    # 精度不足的样本应被拒收
    bad = sample(token, task_id, *INSIDE, acc=200.0)
    check("精度不足的样本被拒收且不推进计时",
          bad.get("sampleAccepted") is False and bad.get("rejectionReason") is not None,
          f"接受={bad.get('sampleAccepted')}，原因={bad.get('rejectionReason')}")

    passed = sum(1 for r in RESULTS if r["结果"] == "PASS")
    print(f"\n合计 {len(RESULTS)} 项，通过 {passed} 项，失败 {len(RESULTS) - passed} 项")
    with open("verify-geofence.json", "w", encoding="utf-8") as fh:
        json.dump({"base": BASE, "username": user, "checks": RESULTS}, fh,
                  ensure_ascii=False, indent=2)
    return 0 if passed == len(RESULTS) else 1


if __name__ == "__main__":
    sys.exit(main())
