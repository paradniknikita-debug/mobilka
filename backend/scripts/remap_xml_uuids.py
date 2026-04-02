"""Одноразовая замена UUID в XML с сохранением ссылок. Запуск: py remap_xml_uuids.py < in.xml"""
import re
import sys
import uuid

UUID_RE = re.compile(
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)


def remap_xml(text: str) -> str:
    seen: dict[str, str] = {}

    def repl(m: re.Match) -> str:
        old = m.group(0)
        if old not in seen:
            seen[old] = str(uuid.uuid4())
        return seen[old]

    return UUID_RE.sub(repl, text)


if __name__ == "__main__":
    data = sys.stdin.read()
    sys.stdout.write(remap_xml(data))
