"""
Аудит изменений карточки опоры (комментарий + вложения) для журнала change_log.
Поддерживает JSON-массив legacy и объект schema=2 с полем items.
"""
from __future__ import annotations

import json
import hashlib
from typing import Any, Dict, List, Optional, Tuple

_TYPE_RU = {
    "photo": "фото",
    "voice": "аудио",
    "schema": "схема",
    "video": "видео",
}


def _norm_comment(s: Optional[str]) -> str:
    return (s or "").strip()


def attachment_items(raw: Optional[str]) -> List[Dict[str, Any]]:
    """Извлекает список вложений из JSON (массив или {schema, items})."""
    if not raw or not str(raw).strip():
        return []
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return []
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    if isinstance(data, dict):
        items = data.get("items")
        if isinstance(items, list):
            return [x for x in items if isinstance(x, dict)]
    return []


def _fingerprint(att: Dict[str, Any]) -> str:
    for k in ("id", "url", "p"):
        v = att.get(k)
        if v:
            return f"{k}:{v}"
    raw = json.dumps(att, sort_keys=True, ensure_ascii=False)
    return "h:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def diff_attachment_lists(
    old_raw: Optional[str], new_raw: Optional[str]
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Возвращает (добавленные элементы, удалённые элементы) по отпечаткам."""
    old_items = attachment_items(old_raw)
    new_items = attachment_items(new_raw)
    old_fps = {_fingerprint(a): a for a in old_items}
    new_fps = {_fingerprint(a): a for a in new_items}
    added = [new_fps[k] for k in new_fps if k not in old_fps]
    removed = [old_fps[k] for k in old_fps if k not in new_fps]
    return added, removed


def _event_kind_for(att: Dict[str, Any], prefix: str) -> str:
    t = (att.get("t") or "photo").lower()
    if t not in _TYPE_RU:
        t = "photo"
    return f"{prefix}_{t}"


def build_pole_card_change_payload(
    old_comment: Optional[str],
    old_attachment_json: Optional[str],
    new_comment: Optional[str],
    new_attachment_json: Optional[str],
    *,
    line_id: Optional[int] = None,
    pole_number: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """
    Собирает payload для ChangeLog или None, если существенных изменений нет.
    """
    oc = _norm_comment(old_comment)
    nc = _norm_comment(new_comment)
    comment_changed = oc != nc

    added, removed = diff_attachment_lists(old_attachment_json, new_attachment_json)
    events: List[Dict[str, Any]] = []

    if comment_changed:
        events.append(
            {
                "kind": "comment_edit",
                "label_ru": "Изменён текст комментария к карточке",
            }
        )

    for a in added:
        tk = (a.get("t") or "photo").lower()
        events.append(
            {
                "kind": _event_kind_for(a, "add"),
                "type": tk,
                "label_ru": f"Добавлено: {_TYPE_RU.get(tk, tk)}",
            }
        )

    for a in removed:
        tk = (a.get("t") or "photo").lower()
        events.append(
            {
                "kind": _event_kind_for(a, "remove"),
                "type": tk,
                "label_ru": f"Удалено: {_TYPE_RU.get(tk, tk)}",
            }
        )

    if not events:
        return None

    # Человекочитаемое резюме для списка журнала
    parts: List[str] = []
    add_counts: Dict[str, int] = {}
    rem_counts: Dict[str, int] = {}
    for e in events:
        k = e.get("kind", "")
        if k == "comment_edit":
            parts.append("комментарий")
            continue
        if k.startswith("add_"):
            t = e.get("type") or "photo"
            add_counts[t] = add_counts.get(t, 0) + 1
        elif k.startswith("remove_"):
            t = e.get("type") or "photo"
            rem_counts[t] = rem_counts.get(t, 0) + 1

    detail_bits: List[str] = []
    if add_counts:
        detail_bits.append(
            "добавлено: "
            + ", ".join(
                f"{_TYPE_RU.get(t, t)} — {n}"
                for t, n in sorted(add_counts.items())
            )
        )
    if rem_counts:
        detail_bits.append(
            "удалено: "
            + ", ".join(
                f"{_TYPE_RU.get(t, t)} — {n}"
                for t, n in sorted(rem_counts.items())
            )
        )
    summary_ru = "Карточка опоры"
    if pole_number:
        summary_ru += f" №{pole_number}"
    if detail_bits:
        summary_ru += ": " + "; ".join(detail_bits)
    elif comment_changed and not add_counts and not rem_counts:
        summary_ru += ": изменён комментарий"

    payload: Dict[str, Any] = {
        "pole_card": True,
        "summary_ru": summary_ru,
        "comment_changed": comment_changed,
        "attachment_events": events,
    }
    if line_id is not None:
        payload["line_id"] = line_id
    if pole_number is not None:
        payload["pole_number"] = pole_number
    return payload
