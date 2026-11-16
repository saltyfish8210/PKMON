"""图件合规守卫：检查 OOA 文档引用的图是否都指向合规目录且已登记。

用法（仓库根目录执行）：
    python docs/stage3/check_diagrams.py [文档路径]

退出码：0 = PASS，1 = 有违规。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    r"C:\Users\taoye\Desktop\软件工程\output\PKMon第三阶段提交_20261119\01_第二阶段文档\src\OOA_OOD正文.md")
REGISTRY = ROOT / "docs" / "stage3" / "作图规范与缺陷清单.md"
COMPLIANT_DIR = "assets/diagrams-v2/"

FIG_RE = re.compile(r"!\[([^\]]+)\]\(([^\)]+)\)")


def main() -> int:
    if not DOC.exists():
        print(f"[FAIL] 文档不存在：{DOC}")
        return 1
    text = DOC.read_text(encoding="utf-8")

    registered = set()
    if REGISTRY.exists():
        for line in REGISTRY.read_text(encoding="utf-8").splitlines():
            for m in re.finditer(r"`?(fig-[a-z0-9\-]+)\.png`?", line):
                registered.add(m.group(1) + ".png")

    total = ok = 0
    problems = []
    for cap, path in FIG_RE.findall(text):
        total += 1
        pure = path.split("?")[0]
        if COMPLIANT_DIR not in pure:
            problems.append(f"{cap}: 未指向合规目录（{pure}）")
            continue
        name = Path(pure).name
        p = Path(r"C:\Users\taoye\Desktop\软件工程\output\PKMon第三阶段提交_20261119") / pure
        if not p.exists():
            problems.append(f"{cap}: 文件不存在（{name}）")
            continue
        if registered and name not in registered:
            problems.append(f"{cap}: 未在作图规范清单登记（{name}）")
            continue
        ok += 1

    print(f"图件总数 {total}，合规 {ok}，问题 {len(problems)}")
    for p in problems:
        print("  -", p)
    if problems:
        print("[FAIL] 存在不合规图件，禁止提交")
        return 1
    print("[PASS] 全部图件指向合规目录且已登记")
    return 0


if __name__ == "__main__":
    sys.exit(main())
