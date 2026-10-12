#!/usr/bin/env python3
"""
docx 폴더의 Word 문서(.docx)를 한꺼번에 Hugo용 Markdown으로 바꿉니다.

사용법 (사이트 폴더에서):
    python tools/convert.py

- docx/ 아래의 하위 폴더 이름이 사이트의 '분류(섹션)'가 됩니다.
    docx/물류관리사/화물자동차법.docx → 사이트의 '물류관리사' 분류
- 결과는 _generated/ 폴더에 만들어집니다(매번 새로 만듦). 직접 고칠 필요 없습니다.
- 필요 프로그램: pandoc (https://pandoc.org/installing.html)
"""
import json
import re
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docx"
OUT = ROOT / "_generated"
FILTER = ROOT / "tools" / "docx2md.lua"
TEMPLATE = ROOT / "tools" / "body.tpl"
TITLES = ROOT / "docx" / "titles.json"          # (선택) 제목을 직접 지정하고 싶을 때

# 파일 이름에서 제목을 만들 때 지울 낱말(대소문자 무시)
REMOVE_WORDS = ["claude", "최종", "final", "수정본", "복사본", "copy"]
DEFAULT_SECTION = "글"                          # docx/ 바로 아래 있는 파일이 들어갈 분류


def title_from_filename(stem: str):
    """'4. 물류정책기본법_해설 claude 260908' → ('물류정책기본법 해설', 4, '2026-09-08')"""
    s = stem.replace("_", " ")
    weight = None
    m = re.match(r"^\s*(\d+)\s*[.)\-]?\s*", s)
    if m:
        weight = int(m.group(1))
        s = s[m.end():]
    date = None
    m = re.search(r"(?<!\d)(\d{8}|\d{6})(?!\d)", s)
    if m:
        d = m.group(1)
        try:
            dt = datetime.strptime(d, "%Y%m%d" if len(d) == 8 else "%y%m%d")
            date = dt.strftime("%Y-%m-%d")
            s = s[: m.start()] + s[m.end():]
        except ValueError:
            pass
    for w in REMOVE_WORDS:
        s = re.sub(rf"(?i)(?<![\w]){re.escape(w)}(?![\w])", " ", s)
    s = re.sub(r"\s+", " ", s).strip(" -_.")
    return s or stem, weight, date


def docx_date(path: Path):
    """Word 파일 속성의 '마지막 수정 날짜'(없으면 만든 날짜)"""
    try:
        with zipfile.ZipFile(path) as z:
            xml = z.read("docProps/core.xml").decode("utf-8", "ignore")
        for tag in ("dcterms:modified", "dcterms:created"):
            m = re.search(rf"<{tag}[^>]*>([^<]+)</{tag}>", xml)
            if m and not m.group(1).startswith("1"):  # 1601 같은 빈 값 제외
                return m.group(1)[:10]
    except Exception:
        pass
    return datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d")


def slugify(s: str):
    s = re.sub(r"[\\/:*?\"<>|#%&{}$!'@`=+\[\]]", "", s)
    s = re.sub(r"[\s.·,]+", "-", s).strip("-")
    return s[:80] or "post"


def yaml_str(s: str):
    return json.dumps(s, ensure_ascii=False)


def convert_one(src: Path, dest_dir: Path, fn_title: str):
    dest_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        "pandoc", str(src.resolve()),
        "-f", "docx",
        "-t", "gfm+raw_html-raw_attribute",
        "--wrap=none",
        "--lua-filter", str(FILTER),
        "--template", str(TEMPLATE),
        "--extract-media", ".",
        "-M", f"fntitle={fn_title}",
    ]
    r = subprocess.run(cmd, cwd=dest_dir, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    out = r.stdout
    head, _, body = out.partition("@@BODY@@\n")
    autotitle = head.replace("@@AUTOTITLE@@", "").strip()
    autotitle = re.sub(r"\\(.)", r"\1", autotitle)          # 마크다운 이스케이프 제거
    return autotitle, body.strip() + "\n"


def main():
    if shutil.which("pandoc") is None:
        sys.exit("pandoc이 설치되어 있지 않습니다: https://pandoc.org/installing.html")
    if not SRC.exists():
        sys.exit(f"원본 폴더가 없습니다: {SRC}")

    overrides = {}
    if TITLES.exists():
        overrides = json.loads(TITLES.read_text(encoding="utf-8"))

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()

    files = sorted(p for p in SRC.rglob("*.docx") if not p.name.startswith("~$"))
    used = set()
    ok = fail = 0
    sections = set()
    for src in files:
        rel = src.relative_to(SRC)
        section = rel.parts[0] if len(rel.parts) > 1 else DEFAULT_SECTION
        sections.add(section)
        fn_title, weight, fn_date = title_from_filename(src.stem)
        try:
            tmp = OUT / section / f".tmp-{ok + fail}"
            title, body = convert_one(src, tmp, fn_title)
            title = overrides.get(src.name, title) or fn_title
            slug_base = slugify(title)
            slug, n = slug_base, 2
            while (section, slug) in used:
                slug, n = f"{slug_base}-{n}", n + 1
            used.add((section, slug))
            bundle = OUT / section / slug
            tmp.rename(bundle)
            if weight is None:
                m = re.match(r"^\s*(\d+)\s*[.)]", title)
                weight = int(m.group(1)) if m else None

            fm = ["---", f"title: {yaml_str(title)}",
                  f"date: {fn_date or docx_date(src)}"]
            if weight is not None:
                fm.append(f"weight: {weight}")
            fm.append(f"source: {yaml_str(str(rel).replace(chr(92), '/'))}")
            fm.append("---")
            (bundle / "index.md").write_text("\n".join(fm) + "\n\n" + body, encoding="utf-8")
            ok += 1
            print(f"  ✔ {rel}  →  {section}/{slug}")
        except Exception as e:
            fail += 1
            print(f"  ✘ {rel}: {e}", file=sys.stderr)

    for section in sections:
        idx = OUT / section / "_index.md"
        if not idx.exists():
            idx.write_text(f"---\ntitle: {yaml_str(section)}\n---\n", encoding="utf-8")

    print(f"\n완료: {ok}개 변환" + (f", {fail}개 실패" if fail else ""))
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
