#!/usr/bin/env python3
"""Localizable.xcstrings の ja/en 網羅監査。
各文字列カタログについて、ja と en の両方の翻訳があるかを確認する。
欠落・未翻訳(state != translated)・%差異を報告する。終了コードは問題があれば1。
"""
import json
import re
import sys
from pathlib import Path

CATALOGS = [
    "HomeMate/Localization/Localizable.xcstrings",
    "HomeMateWidget/Localizable.xcstrings",
]
REQUIRED = ["en", "ja"]
PLACEHOLDER = re.compile(r"%(?:\d+\$)?[@dDuUxXoeEfgGsScaAFp]|%lld|%lu")


def placeholders(value: str) -> int:
    return len(PLACEHOLDER.findall(value or ""))


def is_format_only(key: str) -> bool:
    """キーが数値書式のみ（%lld, %lld/%lld 等、文字を含まない）なら True。"""
    stripped = PLACEHOLDER.sub("", key)
    return not re.search(r"[A-Za-z\u3040-\u30ff\u4e00-\u9fff]", stripped)


def audit(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    source = data.get("sourceLanguage", "en")
    strings = data.get("strings", {})
    problems = 0
    for key, entry in strings.items():
        # 「翻訳不要」マークはスキップ。
        if entry.get("shouldTranslate") is False:
            continue
        # 数値書式のみのキー（Xcode自動生成）はスキップ。
        if is_format_only(key):
            continue
        locs = entry.get("localizations", {})
        counts = {}
        for lang in REQUIRED:
            unit = locs.get(lang, {}).get("stringUnit")
            if unit is None:
                # source 言語かつ値がキー自体で良い場合もあるが、明示を求める。
                if lang == source and not locs:
                    continue
                print(f"[{path.name}] MISSING {lang}: {key}")
                problems += 1
                continue
            state = unit.get("state")
            value = unit.get("value", "")
            if state not in ("translated",):
                print(f"[{path.name}] NOT-TRANSLATED {lang} ({state}): {key}")
                problems += 1
            counts[lang] = placeholders(value)
        if len(counts) == len(REQUIRED) and len(set(counts.values())) > 1:
            print(f"[{path.name}] PLACEHOLDER-MISMATCH {key}: {counts}")
            problems += 1
    return problems


def main() -> int:
    total = 0
    for rel in CATALOGS:
        path = Path(rel)
        if not path.exists():
            print(f"SKIP (not found): {rel}")
            continue
        n = audit(path)
        print(f"{rel}: {n} issue(s)")
        total += n
    print(f"TOTAL: {total} issue(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
