"""
Minimal psycopg2.extras surface used by this repo.

The codebase primarily uses RealDictCursor via:
  conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

In psycopg (v3) this is achieved via `row_factory=psycopg.rows.dict_row`.
"""

from __future__ import annotations

import json
from typing import Any, Callable


try:
    from psycopg.rows import dict_row as _DICT_ROW_FACTORY  # type: ignore
except Exception:  # pragma: no cover
    _DICT_ROW_FACTORY = None  # type: ignore


class RealDictCursor:  # marker class for cursor_factory checks
    pass


class Json:
    """
    Minimal psycopg2.extras.Json-compatible wrapper.

    Supports calls like `Json(payload)` in SQL parameter lists.
    """

    def __init__(self, adapted: Any, dumps: Callable[[Any], str] | None = None):
        self.adapted = adapted
        self._dumps = dumps or json.dumps

    def dumps(self, obj: Any) -> str:
        return self._dumps(obj)

    def __str__(self) -> str:
        return self.dumps(self.adapted)


def _ensure_available() -> None:
    if _DICT_ROW_FACTORY is None:
        raise RuntimeError(
            "psycopg row factories are unavailable. Install psycopg v3:\n"
            "  pip install \"psycopg[binary]\""
        )


def real_dict_cursor_kwargs() -> dict[str, Any]:
    _ensure_available()
    return {"row_factory": _DICT_ROW_FACTORY}


__all__ = ["RealDictCursor", "Json"]

