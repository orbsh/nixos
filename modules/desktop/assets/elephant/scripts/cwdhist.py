#!/usr/bin/env python3
"""elephant 菜单 "cwdhist" 的数据源 + 打开前计数自增。

子命令：
  list  <query>     查询（LIKE 子串过滤，按 count 降序），TAB 三列：
                    <显示名> <TAB> <副标题×count> <TAB> <绝对路径>
  enter <abs_path>  打开某目录前自增访问次数；绝对路径转 ~/path 后
                    命中与 shell cd 同一条记录。

数据/SQL 与 ~/Configuration/nushell/scripts/cwdhist/mod.nu 同源。
仅用 Python 标准库（sqlite3/pathlib），无第三方依赖。
"""
import os
import sqlite3
import sys
from pathlib import Path

HOME = Path.home()
DB = HOME / ".local/share/nushell/cwd_history.sqlite"


def key_of(abs_path):
    """绝对路径 → ~/path 存储形态（命中与 mod.nu 的 env_change.PWD 同一条记录）。"""
    s = str(Path(abs_path).expanduser())
    hs = str(HOME)
    if s.startswith(hs + os.sep):
        return "~" + s[len(hs):]
    return s


def enter(abs_path):
    if not DB.exists():
        return
    con = sqlite3.connect(str(DB))
    try:
        con.execute(
            "insert into cwd_history(cwd) values (?) "
            "on conflict(cwd) do update set "
            "count = count + 1, recent = datetime('now','localtime')",
            (key_of(abs_path),),
        )
        con.commit()
    finally:
        con.close()


def list_dirs(query):
    if not DB.exists():
        return
    con = sqlite3.connect(str(DB))
    try:
        rows = con.execute(
            "select cwd, count from cwd_history "
            "where cwd like ? order by count desc limit 50",
            ("%" + query + "%",),
        ).fetchall()
        for cwd, count in rows:
            abs_ = (HOME / cwd[2:]) if cwd.startswith("~") else Path(cwd)
            if abs_.exists():
                try:
                    print(f"{cwd}\t×{count}\t{abs_}")
                except BrokenPipeError:
                    # 消费者提前关闭 stdout（如 head）时静默退出，不吐 traceback
                    sys.exit(0)
    finally:
        con.close()


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(0)
    cmd, *rest = a
    if cmd == "enter" and rest:
        enter(rest[0])
    elif cmd == "list":
        list_dirs(" ".join(rest))