#!/usr/bin/env python3
"""上游清单工具 —— 手动维护版本的包：查最新 / 校验 hash / 下载镜像 / 改写 Nix 文件

清单在 scripts/upstream.yml（settings + entries），本脚本只做四件事：
查上游最新版本、按 kind 算 hash、下载 mirror 产物、按行模板改写站点文件。

  python3 scripts/upstream.py check  [name]           release/doc：上游最新 tag vs 清单 current
  python3 scripts/upstream.py audit  [name]           mirror：本地文件 hash vs Nix 里记录的值
  python3 scripts/upstream.py hash   <name>           打印本地文件的 hash（按条目的 hash 类型）
  python3 scripts/upstream.py fetch  [name] [--force] 按 upstream 模板下载到 dest
  python3 scripts/upstream.py bump   [name] [--to V] [--write] [--force]
                                                      release：查最新或 --to → 算 hash → 改写 version/url/hash 行
                                                      mirror ：取新版文件 → 重算 hash → 改写 version/url/hash 行
                                                      doc    ：只改写版本串行
                                                      无 name = 遍历全部可更新条目（判定同 check）
  python3 scripts/upstream.py update [name] [--write] [--force]
                                                      全流程：预检 → 取文件 → 改文件 → 推进清单 current

默认 dry-run，只有 --write 才落盘。站点文件按清单里的行模板改写：模板里 {v}/{h}/{u}
的位置视为「任意现有值」，清单与站点漂移时也能一次收敛到目标版本。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml

MANIFEST = "scripts/upstream.yml"
PLACEHOLDER = re.compile(r"\{[vhu]\}")


class ToolError(Exception):
    """工具级错误：打印到 stderr 并以非零退出（对应原来的 nu error make）。"""


# ── 路径 / 清单 ─────────────────────────────────────────────

def repo_root() -> Path:
    """仓库根：$UPSTREAM_REPO > 从 cwd 向上找清单 > 脚本自身所在目录的父目录。

    脚本可能以 store 副本形式被 updateScript 调用（自身目录里没有清单），所以 cwd 优先。
    """
    env = os.environ.get("UPSTREAM_REPO", "")
    if env:
        return Path(env).expanduser().resolve()
    cwd = Path.cwd().resolve()
    for d in (cwd, *cwd.parents):
        if (d / MANIFEST).is_file():
            return d
    return Path(__file__).resolve().parent.parent


def load_manifest() -> dict:
    return yaml.safe_load((repo_root() / MANIFEST).read_text()) or {}


def get_entry(name: str) -> dict:
    entries = load_manifest().get("entries") or {}
    if name not in entries:
        raise ToolError(f"清单里没有条目：{name}")
    return {"name": name, **entries[name]}


def all_names() -> list[str]:
    return list((load_manifest().get("entries") or {}).keys())


def proxy():
    return (load_manifest().get("settings") or {}).get("proxy")


# ── 外部命令 ────────────────────────────────────────────────

def run(cmd: list[str], env: dict | None = None) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise ToolError(f"{cmd[0]} 失败：{(r.stderr or r.stdout or '').strip()}")
    return (r.stdout or "").strip()


def curl(args: list[str]) -> str:
    p = proxy()
    return run(["curl"] + (["--proxy", p] if p else []) + args)


def hash_of(path: Path, kind: str) -> str:
    if kind == "flat":
        return run(["nix", "hash", "file", "--type", "sha256", "--sri", str(path)])
    if kind == "file":
        return run(["nix", "hash", "path", "--type", "sha256", "--sri", str(path)])
    if kind == "tree":
        plain = run(["nix-prefetch-url", "--unpack", "--type", "sha256", f"file://{path}"])
        return run(["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", plain])
    raise ToolError(f"未知 hash 类型：{kind}")


def hash_url(url: str) -> str:
    # nix 的 https 取包走代理（与 flake.nix 的约定一致）
    p = proxy()
    env = None
    if p:
        env = {**os.environ, "https_proxy": p, "http_proxy": p}
    plain = run(["nix-prefetch-url", "--type", "sha256", url], env=env)
    return run(["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", plain])


# ── 产物路径 ────────────────────────────────────────────────

def dest_path(entry: dict) -> Path | None:
    dest = entry.get("dest")
    if not dest:
        return None
    name = re.sub(r"^~", os.environ.get("HOME", "~"), dest)
    filename = (entry.get("file") or "").replace("{v}", str(entry.get("current") or ""))
    return Path(name) / filename


def local_file(entry: dict) -> Path | None:
    p = dest_path(entry)
    return p if p and p.exists() else None


def mirror_url(entry: dict) -> str:
    """镜像地址：条目写了完整 url 就用它，否则 <settings.mirror-base>/<dest 目录名>/<file>。"""
    explicit = entry.get("url")
    if explicit:
        return explicit
    base = (load_manifest().get("settings") or {}).get("mirror-base")
    if not base:
        raise ToolError("清单没配 settings.mirror-base，且该条目也没写 url")
    dest = entry.get("dest")
    if not dest:
        raise ToolError("条目没有 dest，无法推导镜像地址")
    sub = Path(re.sub(r"^~", os.environ.get("HOME", "~"), dest)).name
    return f"{base.strip('/')}/{sub}/{entry['file']}"


def unversioned_file(entry: dict) -> bool:
    """文件名不含 {v}（jcode/wechat 类）：换版本时同名覆盖，需要 force。"""
    return "{v}" not in (entry.get("file") or "")


def download(entry: dict, version: str, force: bool) -> Path:
    target = dest_path({**entry, "current": version})
    if target is None:
        raise ToolError("条目没有 dest，无法下载")
    if target.exists() and not force:
        print(f"  已存在，跳过下载：{target}")
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    url = (entry.get("upstream") or "").replace("{v}", version)
    print(f"  下载：{url}")
    print(f"    目标：{target}（force={'true' if force else 'false'}）")
    curl(["-fL", "--create-dirs", "-o", str(target), url])
    print(f"  下载完成：{target}（{human_size(target.stat().st_size)}）")
    return target


def human_size(n: int) -> str:
    size = float(n)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1000 or unit == "GB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1000
    return f"{size:.1f} GB"


# ── 站点文件 ────────────────────────────────────────────────

def site_files(entry: dict) -> list[str]:
    if "sites" in entry:
        return [next(iter(s.values())) for s in entry["sites"]]
    if "site" in entry:
        return [entry["site"]]
    return []


def recorded_hash(rel: str, context: str) -> str | None:
    path = repo_root() / rel
    if not path.is_file():
        raise ToolError(f"站点文件不存在：{rel}")
    text = path.read_text()
    if context:
        idx = text.find(context)
        if idx >= 0:
            text = text[idx:]
    m = re.search(r"sha256-[A-Za-z0-9+/=]+", text)
    return m.group(0) if m else None


def save_lines(path: Path, lines: list[str], trailing_newline: bool) -> None:
    path.write_text("\n".join(lines) + ("\n" if trailing_newline else ""))


def set_template_line(path: Path, template: str, value: str, context: str) -> bool:
    """按模板改写行内被引号括住的值；找不到可改的行返回 False。

    只替换行内命中片段，保留缩进与行尾分号（整行替换会吃掉它们，生成非法 nix）。
    """
    parts = PLACEHOLDER.split(template)
    if len(parts) != 2:
        raise ToolError(f"模板里缺 {{v}}/{{h}}/{{u}} 占位：{template}")
    pre, post = parts

    raw = path.read_text()
    trailing_newline = raw.endswith("\n")
    lines = raw.splitlines()

    if context:
        start = next((i for i, line in enumerate(lines) if context in line), None)
        if start is None:
            return False
    else:
        start = 0

    hits = [i for i in range(start, len(lines)) if pre in lines[i]]
    if not hits:
        return False
    # 有 context 锚点时只改锚点后的第一处；无锚点时改全部
    targets = {hits[0]} if context else set(hits)

    for i in targets:
        line = lines[i]
        at = line.find(pre)
        after = line[at + len(pre):]
        tail = after.find(post)
        if tail < 0:
            continue
        lines[i] = line[: at + len(pre)] + value + after[tail:]

    save_lines(path, lines, trailing_newline)
    return True


def set_manifest_current(name: str, version: str) -> None:
    """清单里该条目的 current 行改写成新版本（其余行与注释不动）。"""
    path = repo_root() / MANIFEST
    raw = path.read_text()
    trailing_newline = raw.endswith("\n")
    lines = raw.splitlines()

    start = next((i for i, line in enumerate(lines) if line.startswith(f"  {name}:")), None)
    if start is None:
        print(f"  清单里找不到 {name} 条目，current 未改")
        return
    stop = next(
        (i for i in range(start + 1, len(lines)) if re.match(r"^  [A-Za-z0-9_-]+:$", lines[i])),
        len(lines) - 1,
    )
    for i in range(start + 1, stop + 1):
        if not lines[i].strip().startswith("current:"):
            continue
        indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
        m = re.search(r'current:\s*(?:"[^"]*"|null)\s*(#.*)?$', lines[i])
        note = (m.group(1) or "") if m else ""
        lines[i] = f'{indent}current: "{version}"' + (f" {note}" if note else "")

    save_lines(path, lines, trailing_newline)
    print(f"  清单 current -> {version}")


def apply_site(name: str, site: str, entry: dict, pairs: list[tuple[str, str, str]]) -> bool:
    """按 (模板, 新值, 标签) 逐字段改写一个站点文件；任何一处失败都返回 False 并告警。"""
    path = repo_root() / site
    context = entry.get("context") or ""
    ok = True
    for template, value, label in pairs:
        if set_template_line(path, template, value, context):
            print(f"  {site} {label} → {value}")
        else:
            print(f"  ⚠ {site} 找不到{label}（模板 {template}）")
            ok = False
    return ok


# ── 上游版本 ────────────────────────────────────────────────

def latest_tag(entry: dict) -> str | None:
    repo = entry.get("repo")
    if not repo:
        return None
    # 默认看正式 release；prerelease 条目（ferron 跑在 3.x beta/rc）取含预发布的最新
    api = (
        f"https://api.github.com/repos/{repo}/releases?per_page=1"
        if entry.get("prerelease")
        else f"https://api.github.com/repos/{repo}/releases/latest"
    )
    parsed = json.loads(curl(["-fsSL", api]))
    tag = parsed[0]["tag_name"] if entry.get("prerelease") else parsed["tag_name"]
    # tag 模板 {v} → 版本；v{v} → 去掉 v 前缀
    prefix = (entry.get("tag") or "{v}").split("{v}")[0]
    return re.sub("^" + re.escape(prefix), "", tag)


def stale_entries(verbose: bool) -> list[dict]:
    """可更新条目：判定与 check 同一套（pinned-tag、无 repo 的 mirror 一律不参与）。"""
    out = []
    for name in all_names():
        entry = get_entry(name)
        pinned = bool(entry.get("pinned-tag"))
        blind = entry.get("kind") == "mirror" and not entry.get("repo")
        if pinned or blind:
            if verbose:
                print(f"  跳过 {name}（{'pinned-tag' if pinned else '无 repo，不查版本'}）")
            continue
        current = str(entry.get("current") or "")
        if verbose:
            print(f"  检查 {name}：{current} → ", end="", flush=True)
        try:
            latest = latest_tag(entry)
        except ToolError:
            latest = None
        if verbose:
            if latest is None:
                print("?")
            elif latest == current:
                print(f"{latest} ok")
            else:
                print(f"{latest} 可更新")
        if latest is None or latest == current:
            continue
        out.append({"name": name, "entry": entry, "latest": latest})
    return out


def target_version(entry: dict, to: str | None) -> str:
    """目标版本：--to > 上游最新 > 清单 current（无 repo 的 mirror 只能重算 hash）。"""
    current = str(entry.get("current") or "")
    try:
        latest = latest_tag(entry)
    except ToolError:
        latest = None
    return to or latest or current


# ── 命令：check / audit / hash / fetch ─────────────────────

def pad(text, width: int) -> str:
    """按字符数补齐（与原来 nu 的 fill -w 一致：按 codepoint 而非显示宽度）。"""
    s = str(text)
    return s + " " * max(0, width - len(s))


def cmd_check(name: str | None) -> None:
    names = [name] if name else all_names()
    print("条目               当前          上游最新      状态")
    for n in names:
        entry = get_entry(n)
        if entry.get("kind") == "mirror" and not entry.get("repo"):
            # 不静默：漏填 repo 的条目要看得见（vivaldi/wechat 属设计内，上游不在 GitHub）
            print(pad(n, 18) + pad(entry.get("current") or "-", 14) + pad("-", 14) + "无 repo，不查版本")
            continue
        if entry.get("pinned-tag"):
            print(
                pad(n, 18)
                + pad(entry.get("current") or "-", 14)
                + pad(f"固定 tag：{entry.get('tag')}", 14)
                + "—"
            )
            continue
        try:
            latest = latest_tag(entry)
        except ToolError:
            latest = None
        current = str(entry.get("current") or "-")
        state = "?" if latest is None else ("ok" if latest == current else "可更新")
        print(pad(n, 18) + pad(current, 14) + pad(latest or "-", 14) + state)


def cmd_audit(name: str | None) -> None:
    names = [name] if name else all_names()
    print("条目               本地文件 hash                                 记录值                                        状态")
    for n in names:
        entry = get_entry(n)
        if entry.get("kind") != "mirror":
            continue
        path = local_file(entry)
        if path is None:
            print(pad(n, 18) + "缺本地文件")
            continue
        digest = hash_of(path, entry.get("hash") or "flat")
        recorded = [
            h for h in (recorded_hash(s, entry.get("context") or "") for s in site_files(entry)) if h
        ]
        state = "ok" if digest in recorded else "不一致"
        print(pad(n, 18) + " " + pad(digest, 46) + " " + pad(",".join(recorded), 46) + " " + state)


def cmd_hash(name: str) -> None:
    entry = get_entry(name)
    path = local_file(entry)
    if path is None:
        raise ToolError(f"本地文件不存在：{dest_path(entry)}")
    print(hash_of(path, entry.get("hash") or "flat"))


def cmd_fetch(name: str | None, force: bool) -> None:
    if name:
        entry = get_entry(name)
        if entry.get("kind") != "mirror":
            raise ToolError(
                f"{name} 是 {entry.get('kind')} 条目，没有要下载到 dest 的产物"
                "（release 由 Nix 的 fetchurl 取，doc 只有版本串），fetch 只用于 mirror"
            )
        if not entry.get("upstream"):
            raise ToolError(f"{name} 没配 upstream，无法下载")
        download(entry, str(entry.get("current") or ""), force)
        return

    targets = [x for x in stale_entries(True) if x["entry"].get("kind") == "mirror"]
    if not targets:
        print("没有可更新的 mirror 条目")
        return
    for x in targets:
        entry = x["entry"]
        if not entry.get("upstream"):
            print(f"{x['name']}：没配 upstream，跳过")
            continue
        print(f"{x['name']}：{entry.get('current')} -> {x['latest']}")
        download({**entry, "current": x["latest"]}, x["latest"], unversioned_file(entry) or force)


# ── 命令：bump / update ────────────────────────────────────

def bump_entry(name: str, version: str, write: bool, force: bool) -> None:
    entry = get_entry(name)
    kind = entry.get("kind")
    sites = site_files(entry)
    if not sites:
        raise ToolError(f"{name} 没配 site")
    current = str(entry.get("current") or "")

    if kind == "release":
        if version == current:
            print(f"  {name} 已是最新（{version}）")
            return
        url = entry["url"].replace("{v}", version)
        print(f"  url : {url}")
        print("  计算 hash（下载资产，稍等）…")
        digest = hash_url(url)
        print(f"  hash: {digest}")
        if not write:
            print("  (dry-run，未落盘)")
            return
        ok = True
        for site in sites:
            pairs = [(entry["version-line"], version, "版本行")]
            if entry.get("url-line"):
                pairs.append((entry["url-line"], url, "url"))
            pairs.append((entry["hash-line"], digest, "hash"))
            ok = apply_site(name, site, entry, pairs) and ok
        if ok:
            print(f"  已写入：{', '.join(sites)}")
            set_manifest_current(name, version)
        else:
            print("  有站点文件的版本行未改写，清单 current 保持不动（避免台账与实际版本脱节）")
        return

    if kind == "doc":
        # doc 条目：版本串只出现在站点文件的脚本文本里（无产物可下载），bump = 改写那一行
        if not entry.get("version-line"):
            raise ToolError(f"{name} 没配 version-line")
        if version == current:
            print(f"{name} 已是最新（{version}）")
            return
        print(
            "  站点行: "
            + entry["version-line"].replace("{v}", current)
            + " -> "
            + entry["version-line"].replace("{v}", version)
        )
        if not write:
            print("  (dry-run，未落盘)")
            return
        ok = True
        for site in sites:
            ok = apply_site(name, site, entry, [(entry["version-line"], version, "版本行")]) and ok
        if ok:
            set_manifest_current(name, version)
        else:
            print("  站点文件的版本行未改写，清单 current 保持不动（避免台账与实际版本脱节）")
        return

    if kind == "mirror":
        if not version:
            raise ToolError(f"{name} 清单没有 current，按需用 --to 指定版本")
        # 版本变了（或 --force）先取新版文件；文件名不含 {v} 的条目同名覆盖，必须 force
        if version != current or force:
            if not entry.get("upstream"):
                raise ToolError(f"{name} 没配 upstream，无法下载；手工放好文件后再 bump")
            if not write:
                print(f"  将下载新版本 {version}（dry-run 不下载；hash 待新文件就位后再算）")
                return
            download({**entry, "current": version}, version, version == current or force or unversioned_file(entry))
        path = dest_path({**entry, "current": version})
        if path is None or not path.exists():
            raise ToolError(f"本地文件不存在：{path}；先 python3 scripts/upstream.py fetch {name}")
        digest = hash_of(path, entry.get("hash") or "flat")
        new_url = mirror_url(entry).replace("{v}", version)
        print(f"  本地文件: {path}")
        print(f"  新 hash : {digest}（kind={entry.get('hash')}）")
        if new_url != mirror_url(entry).replace("{v}", current):
            print(f"  新 url  : {new_url}")
        if not write:
            print("  (dry-run，未落盘)")
            return
        ok = True
        for site in sites:
            pairs = []
            if entry.get("version-line"):
                pairs.append((entry["version-line"], version, "版本行"))
            pairs.append((entry["hash-line"], digest, "hash"))
            if entry.get("url-line"):
                pairs.append((entry["url-line"], new_url, "url"))
            ok = apply_site(name, site, entry, pairs) and ok
        if ok:
            set_manifest_current(name, version)
        else:
            print("  版本行未改写，清单 current 保持不动（避免台账与实际版本脱节）")
        return

    raise ToolError(f"未知 kind：{kind}")


def cmd_bump(name: str | None, to: str | None, write: bool, force: bool) -> None:
    if name:
        entry = get_entry(name)
        version = target_version(entry, to)
        if not version:
            raise ToolError("取不到目标版本，用 --to 指定")
        print(f"== {name}（{entry.get('kind')}）{entry.get('current')} → {version} ==")
        bump_entry(name, version, write, force)
        return

    print("扫描可更新条目（逐条查上游，网络请求，稍等）")
    targets = stale_entries(True)
    if not targets:
        print("全部条目已是最新")
        return
    print("可更新：" + ", ".join(t["name"] for t in targets))
    for t in targets:
        print()
        print(f"== {t['name']}（{t['entry'].get('kind')}）{t['entry'].get('current')} → {t['latest']} ==")
        try:
            bump_entry(t["name"], t["latest"], write, force)
        except ToolError as exc:
            print(f"  ⚠ 失败：{exc}")


def cmd_update(name: str | None, write: bool, force: bool) -> None:
    if name:
        entry = get_entry(name)
        version = target_version(entry, None)
        if not version:
            raise ToolError("取不到目标版本")
        print(f"== {name}（{entry.get('kind')}）{entry.get('current')} → {version} ==")
        bump_entry(name, version or "", write, force)
        return

    print(f"全流程更新（write={'true' if write else 'false'}，逐条查上游并处理）")
    targets = stale_entries(True)
    if not targets:
        print("全部条目已是最新")
        return
    print("可更新：" + ", ".join(t["name"] for t in targets))
    failed = []
    for t in targets:
        print()
        print(f"== {t['name']}（{t['entry'].get('kind')}）{t['entry'].get('current')} → {t['latest']} ==")
        try:
            bump_entry(t["name"], t["latest"], write, force)
        except ToolError as exc:
            print(f"  ⚠ 失败：{exc}")
            failed.append(t["name"])
    if not write:
        print("dry-run：加 --write 落盘")
    else:
        print("已写入。下一步（人工）：nh os build .#<host>（不要自行 switch）；mirror 条目换版本后记得重启对应服务（herdr server 等）。")
    if failed:
        print(f"失败条目：{', '.join(failed)}")


# ── CLI ────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="upstream.py",
        description="上游清单工具：查最新 / 校验 hash / 下载镜像 / 改写 Nix 文件（默认 dry-run）",
    )
    sub = parser.add_subparsers(dest="cmd")

    for cmd, help_text in (
        ("check", "release/doc：上游最新 tag vs 清单 current"),
        ("audit", "mirror：本地文件 hash vs Nix 里记录的值"),
    ):
        p = sub.add_parser(cmd, help=help_text)
        p.add_argument("name", nargs="?")

    p_hash = sub.add_parser("hash", help="打印本地文件的 hash（按条目的 hash 类型）")
    p_hash.add_argument("name")

    p_fetch = sub.add_parser("fetch", help="按 upstream 模板下载到 dest；无 name = 遍历可更新的 mirror 条目")
    p_fetch.add_argument("name", nargs="?")
    p_fetch.add_argument("--force", action="store_true", help="文件已存在也重新下载")

    p_bump = sub.add_parser("bump", help="改写站点文件（version/url/hash）并推进清单 current")
    p_bump.add_argument("name", nargs="?")
    p_bump.add_argument("--to", help="指定目标版本（默认取上游最新）")
    p_bump.add_argument("--write", action="store_true", help="落盘（默认 dry-run）")
    p_bump.add_argument("--force", action="store_true", help="同名文件也重新下载")

    p_update = sub.add_parser("update", help="全流程：预检 → 取文件 → 改文件 → 推进 current")
    p_update.add_argument("name", nargs="?")
    p_update.add_argument("--write", action="store_true", help="落盘（默认 dry-run）")
    p_update.add_argument("--force", action="store_true", help="同名文件也重新下载")

    args = parser.parse_args(argv)
    if args.cmd is None:
        parser.print_help()
        return 0

    if args.cmd == "check":
        cmd_check(args.name)
    elif args.cmd == "audit":
        cmd_audit(args.name)
    elif args.cmd == "hash":
        cmd_hash(args.name)
    elif args.cmd == "fetch":
        cmd_fetch(args.name, args.force)
    elif args.cmd == "bump":
        cmd_bump(args.name, args.to, args.write, args.force)
    elif args.cmd == "update":
        cmd_update(args.name, args.write, args.force)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except ToolError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
    except BrokenPipeError:
        # 输出被 head/wl-copy 之类提前关掉：安静退出，别抛栈
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(141)