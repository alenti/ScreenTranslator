#!/usr/bin/env python3
"""Convert a filtered CC-CEDICT text file sample into SQLite.

This is a proof-of-concept tool for evaluating CC-CEDICT as a local
Chinese-to-English fallback dictionary for Quick Look Mode. It intentionally
does not integrate with the iOS app target or bundle generated data.
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path


DEFAULT_TERMS = [
    "购物车",
    "支付",
    "发货",
    "包装",
    "仓库",
    "国际运输",
    "高跟鞋",
    "优惠券",
    "退款",
    "地址",
    "标签",
    "外箱",
    "货物",
    "运输",
    "木架",
    "入仓费",
    "私人仓",
]

CEDICT_LINE_PATTERN = re.compile(
    r"^(?P<traditional>\S+)\s+"
    r"(?P<simplified>\S+)\s+"
    r"\[(?P<pinyin>[^\]]+)\]\s+"
    r"/(?P<definitions>.*)/$"
)


@dataclass(frozen=True)
class CEDICTEntry:
    traditional: str
    simplified: str
    source_compact: str
    pinyin: str
    english: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Parse CC-CEDICT and write a small SQLite sample database for "
            "Quick Look dictionary source evaluation."
        )
    )
    parser.add_argument(
        "cedict_path",
        type=Path,
        help="Path to a local CC-CEDICT text file, e.g. cedict_ts.u8.",
    )
    parser.add_argument(
        "--terms",
        default=",".join(DEFAULT_TERMS),
        help=(
            "Comma-separated Chinese terms to export. Defaults to the current "
            "Quick Look logistics/shopping sample set."
        ),
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Export all valid CC-CEDICT entries instead of filtering terms.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("QuickLookCEDICTSample.sqlite"),
        help="Output SQLite path. Defaults to QuickLookCEDICTSample.sqlite.",
    )
    return parser.parse_args()


def normalized_source(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text)
    invisible = {
        "\u200b",
        "\u200c",
        "\u200d",
        "\u2060",
        "\ufeff",
    }
    return "".join(
        character
        for character in normalized
        if character not in invisible and not character.isspace()
    )


def parse_terms(terms_argument: str) -> set[str]:
    return {
        normalized_source(term)
        for term in terms_argument.split(",")
        if normalized_source(term)
    }


def parse_cedict_line(line: str) -> CEDICTEntry | None:
    stripped = line.strip()

    if not stripped or stripped.startswith("#"):
        return None

    match = CEDICT_LINE_PATTERN.match(stripped)
    if match is None:
        return None

    traditional = normalized_source(match.group("traditional"))
    simplified = normalized_source(match.group("simplified"))
    definitions = [
        definition.strip()
        for definition in match.group("definitions").split("/")
        if definition.strip()
    ]

    if not traditional or not simplified or not definitions:
        return None

    return CEDICTEntry(
        traditional=traditional,
        simplified=simplified,
        source_compact=normalized_source(simplified),
        pinyin=match.group("pinyin").strip(),
        english="; ".join(definitions),
    )


def iter_entries(
    cedict_path: Path,
    terms: set[str] | None,
) -> tuple[list[CEDICTEntry], int, int]:
    entries: list[CEDICTEntry] = []
    skipped_invalid = 0
    parsed_valid = 0

    with cedict_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            entry = parse_cedict_line(line)

            if entry is None:
                if line.strip() and not line.lstrip().startswith("#"):
                    skipped_invalid += 1
                continue

            parsed_valid += 1

            if terms is not None:
                if entry.simplified not in terms and entry.traditional not in terms:
                    continue

            entries.append(entry)

    return entries, parsed_valid, skipped_invalid


def create_database(output_path: Path, entries: list[CEDICTEntry]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if output_path.exists():
        output_path.unlink()

    connection = sqlite3.connect(output_path)

    try:
        connection.executescript(
            """
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                simplified TEXT,
                traditional TEXT,
                sourceCompact TEXT,
                pinyin TEXT,
                english TEXT,
                sourceKind TEXT DEFAULT 'cc_cedict',
                licenseSource TEXT DEFAULT 'CC-CEDICT CC BY-SA',
                priority INTEGER DEFAULT 0
            );

            CREATE INDEX idx_entries_simplified ON entries(simplified);
            CREATE INDEX idx_entries_traditional ON entries(traditional);
            CREATE INDEX idx_entries_sourceCompact ON entries(sourceCompact);
            """
        )
        connection.executemany(
            """
            INSERT INTO entries (
                simplified,
                traditional,
                sourceCompact,
                pinyin,
                english
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                (
                    entry.simplified,
                    entry.traditional,
                    entry.source_compact,
                    entry.pinyin,
                    entry.english,
                )
                for entry in entries
            ],
        )
        connection.commit()
    finally:
        connection.close()


def print_lookup_results(output_path: Path, terms: list[str]) -> None:
    connection = sqlite3.connect(output_path)
    connection.row_factory = sqlite3.Row

    try:
        print("\nSample lookup results")
        print("=====================")

        for term in terms:
            normalized_term = normalized_source(term)
            rows = connection.execute(
                """
                SELECT simplified, traditional, pinyin, english
                FROM entries
                WHERE simplified = ?
                   OR traditional = ?
                   OR sourceCompact = ?
                ORDER BY id
                """,
                (normalized_term, normalized_term, normalized_term),
            ).fetchall()

            if not rows:
                print(f"{term}: MISSING")
                continue

            for index, row in enumerate(rows, start=1):
                suffix = "" if len(rows) == 1 else f" #{index}"
                print(
                    f"{term}{suffix}: {row['pinyin']} | {row['english']}"
                )
    finally:
        connection.close()


def main() -> int:
    args = parse_args()
    cedict_path: Path = args.cedict_path

    if not cedict_path.is_file():
        print(f"Input file not found: {cedict_path}", file=sys.stderr)
        return 2

    filter_terms = None if args.all else parse_terms(args.terms)
    lookup_terms = [
        term.strip()
        for term in args.terms.split(",")
        if term.strip()
    ]
    entries, parsed_valid, skipped_invalid = iter_entries(
        cedict_path,
        filter_terms,
    )

    create_database(args.output, entries)

    print(f"Input: {cedict_path}")
    print(f"Output: {args.output}")
    print(f"Valid CC-CEDICT entries parsed: {parsed_valid}")
    print(f"Invalid non-comment lines skipped: {skipped_invalid}")
    print(f"Rows written: {len(entries)}")
    print(f"Filter: {'ALL entries' if filter_terms is None else ','.join(lookup_terms)}")

    print_lookup_results(args.output, lookup_terms)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
