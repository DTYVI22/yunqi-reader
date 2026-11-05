#!/usr/bin/env python3
"""把 legado 书源规则文档（Typora 导出 HTML）转成可检索的 Markdown。

用法：python tools/convert_legado_doc.py <input.html> <output.md>
"""
from __future__ import annotations

import re
import sys

from lxml import html as lxml_html


def text_of(el) -> str:
    return "".join(el.itertext())


def clean(text: str) -> str:
    text = text.replace("\u00a0", " ")
    return re.sub(r"[ \t]+", " ", text).strip()


def walk(node, out: list[str]) -> None:
    for child in node:
        tag = child.tag if isinstance(child.tag, str) else ""
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            level = int(tag[1])
            title = clean(text_of(child))
            if title:
                out.append("")
                out.append("#" * level + " " + title)
                out.append("")
        elif tag == "p":
            body = clean(text_of(child))
            if body:
                # Typora 导出会把整段列表压成一个超长段落，按文档自己的分隔符
                # 拆行，否则后面根本没法按行检索。
                for piece in re.split(r"(?=[·▲])", body):
                    piece = piece.strip()
                    if piece:
                        out.append(piece)
        elif tag == "pre":
            code = text_of(child).rstrip()
            out.append("```")
            out.append(code)
            out.append("```")
        elif tag in ("ul", "ol"):
            for index, li in enumerate(child):
                if not isinstance(li.tag, str) or li.tag != "li":
                    continue
                marker = "-" if tag == "ul" else f"{index + 1}."
                body = clean(text_of(li))
                if body:
                    out.append(f"{marker} {body}")
        elif tag == "blockquote":
            body = clean(text_of(child))
            if body:
                out.extend("> " + line for line in body.splitlines())
        elif tag == "table":
            for row in child.iter("tr"):
                cells = [
                    clean(text_of(cell))
                    for cell in row
                    if isinstance(cell.tag, str) and cell.tag in ("td", "th")
                ]
                if cells:
                    out.append("| " + " | ".join(cells) + " |")
        elif tag in ("div", "section", "article", "html", "body"):
            walk(child, out)
        else:
            body = clean(text_of(child))
            if body and len(body) < 200:
                out.append(body)


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    source, target = sys.argv[1], sys.argv[2]
    with open(source, "rb") as handle:
        document = lxml_html.fromstring(handle.read())

    roots = document.xpath('//div[@id="write"]')
    root = roots[0] if roots else document.body

    lines: list[str] = []
    walk(root, lines)

    # 合并连续空行
    cleaned: list[str] = []
    for line in lines:
        if line == "" and cleaned and cleaned[-1] == "":
            continue
        cleaned.append(line)

    with open(target, "w", encoding="utf-8") as handle:
        handle.write("\n".join(cleaned).strip() + "\n")

    print(f"wrote {target}: {len(cleaned)} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
