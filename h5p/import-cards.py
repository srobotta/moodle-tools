#!/usr/bin/env python3

# Imports a wordlist from a open office document into a dialog-card h5p object.
# Usage: import-cards.py [-h] [--front <letter>] [--back <letter>] [--row <number>]
#                        [--sheet <name>] [--title <text>] h5p_file ods_file
# Input arguments are:
#
# h5p_file: File with the dialog-card object (will be overwritten with the new
#           card content).
# ods_file: Open office spreadsheet document file.
# --front:  The column letter (defaults to A) for the items that go on the
#           front side of the cards (the questions).
# --back:   The column letter (defaults to B) for the items that go on the
#           backside of the cards (the answers).
# --row:    The number of the row where to start the import (to skip header lines,
#           defaults to 1).
# --sheet:  The name of the sheet in the open office spreadsheet to use, defaults
#           to the first sheet in the spreadsheed document.
# --title:  The title to set in the h5p (content/content.json and h5p.json). When
#           omitted, the existing title is left unchanged.

import argparse
import html
import json
import os
import shutil
import sys
import tempfile
import zipfile

from odf.opendocument import load
from odf.table import Table, TableRow, TableCell
from odf.text import P


def column_letter_to_index(letter):
    """Convert a spreadsheet column letter (A, B, ..., Z, AA, ...) to a
    zero-based column index."""
    letter = letter.strip().upper()
    if not letter or not letter.isalpha():
        raise ValueError(f"Invalid column letter: {letter!r}")
    index = 0
    for char in letter:
        index = index * 26 + (ord(char) - ord("A") + 1)
    return index - 1


def cell_text(cell):
    """Extract the plain text content of a table cell, joining the text of all
    paragraphs it contains."""
    paragraphs = []
    for p in cell.getElementsByType(P):
        # str() on the paragraph node yields its concatenated text content.
        paragraphs.append(str(p))
    return "\n".join(paragraphs)


def sheet_to_grid(table):
    """Turn an ODS table into a list of rows, where each row is a list of the
    cell text values. Expands the repeat-count shorthand that ODS uses for
    consecutive identical rows/cells."""
    grid = []
    for row in table.getElementsByType(TableRow):
        row_repeat = int(row.getAttribute("numberrowsrepeated") or 1)
        cells = []
        for cell in row.getElementsByType(TableCell):
            cell_repeat = int(cell.getAttribute("numbercolumnsrepeated") or 1)
            text = cell_text(cell)
            cells.extend([text] * cell_repeat)
        # Trailing empty repeated rows (often a huge number) would blow up the
        # grid, so cap the repeat for a row that has no content.
        if not any(c.strip() for c in cells):
            row_repeat = 1
        for _ in range(row_repeat):
            grid.append(list(cells))
    return grid


def find_sheet(doc, sheet_name):
    """Return the table whose name matches sheet_name. When sheet_name is None,
    return the first sheet in the document. Raise if nothing matches."""
    tables = doc.getElementsByType(Table)
    if not tables:
        raise ValueError("The document contains no sheets.")
    if sheet_name is None:
        return tables[0]
    for table in tables:
        if table.getAttribute("name") == sheet_name:
            return table
    available = [t.getAttribute("name") for t in tables]
    raise ValueError(
        f"Sheet {sheet_name!r} not found. Available sheets: {available}"
    )


def extract_cards(ods_path, front_column, back_column, start_row, sheet_name):
    """Read the open office document and return a list of [front, back] pairs,
    one per card. Rows where both sides are empty are skipped."""
    doc = load(ods_path)
    table = find_sheet(doc, sheet_name)
    grid = sheet_to_grid(table)

    front_index = column_letter_to_index(front_column)
    back_index = column_letter_to_index(back_column)

    cards = []
    # start_row is a 1-based spreadsheet row number; convert to a 0-based index.
    for row in grid[start_row - 1:]:
        front = row[front_index].strip() if front_index < len(row) else ""
        back = row[back_index].strip() if back_index < len(row) else ""
        if not front and not back:
            continue
        cards.append([front, back])
    return cards


# Paths of the JSON files inside the h5p zip archive.
CONTENT_PATH = "content/content.json"
H5P_PATH = "h5p.json"


def as_card_html(value):
    """Wrap a card side's plain text in the centered paragraph markup that the
    dialog-card content uses, escaping any HTML-significant characters."""
    return f'<p style="text-align:center;">{html.escape(value)}</p>'


def write_cards_to_h5p(h5p_path, cards, title=None):
    """Replace the `dialogs` list inside the h5p's content.json with one entry
    per extracted card, then write the archive back in place. When a title is
    given, it is also written to the `title` property of both content.json
    (wrapped in a paragraph) and h5p.json (as plain text). All other files in
    the archive and all other properties are left untouched."""
    with zipfile.ZipFile(h5p_path, "r") as archive:
        names = archive.namelist()
        if CONTENT_PATH not in names:
            raise ValueError(
                f"{CONTENT_PATH!r} not found in {h5p_path!r}; is this a "
                "dialog-card h5p file?"
            )
        content = json.loads(archive.read(CONTENT_PATH).decode("utf-8"))
        h5p_meta = json.loads(archive.read(H5P_PATH).decode("utf-8"))

    content["dialogs"] = [
        {
            "text": as_card_html(front),
            "answer": as_card_html(back),
            "tips": {},
        }
        for front, back in cards
    ]
    if title is not None:
        content["title"] = f"<p>{html.escape(title)}</p>"
        h5p_meta["title"] = title

    # Map of archive member name -> its new bytes. Members not listed here are
    # copied through unchanged.
    replacements = {
        CONTENT_PATH: json.dumps(content, ensure_ascii=False).encode("utf-8"),
    }
    if title is not None:
        replacements[H5P_PATH] = json.dumps(
            h5p_meta, ensure_ascii=False
        ).encode("utf-8")

    # Rewrite the archive to a temp file (zip entries cannot be replaced in
    # place), copying every member unchanged except the ones we replace, then
    # move it over the original.
    fd, tmp_path = tempfile.mkstemp(suffix=".h5p", dir=os.path.dirname(h5p_path) or ".")
    os.close(fd)
    try:
        with zipfile.ZipFile(h5p_path, "r") as src, zipfile.ZipFile(
            tmp_path, "w", zipfile.ZIP_DEFLATED
        ) as dst:
            for item in src.infolist():
                if item.filename in replacements:
                    dst.writestr(item, replacements[item.filename])
                else:
                    dst.writestr(item, src.read(item.filename))
        shutil.move(tmp_path, h5p_path)
    except BaseException:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Import a wordlist from an open office document into a "
        "dialog-card h5p object."
    )
    parser.add_argument("h5p_file", help="the h5p file with the dialog-card object")
    parser.add_argument("ods_file", help="the open office document file")
    parser.add_argument(
        "--front",
        dest="front_column",
        default="A",
        help="column letter for the front side (the questions), default A",
    )
    parser.add_argument(
        "--back",
        dest="back_column",
        default="B",
        help="column letter for the back side (the answers), default B",
    )
    parser.add_argument(
        "--row",
        type=int,
        default=1,
        help="row number where the import starts (1-based), default 1",
    )
    parser.add_argument(
        "--sheet",
        default=None,
        help="name of the sheet to use; defaults to the first sheet",
    )
    parser.add_argument(
        "--title",
        default=None,
        help="title to set in the h5p (content.json and h5p.json); "
        "left unchanged when omitted",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    cards = extract_cards(
        args.ods_file,
        args.front_column,
        args.back_column,
        args.row,
        args.sheet,
    )

    for front, back in cards:
        print(f"{front!r} -> {back!r}")
    print(f"\n{len(cards)} cards extracted.", file=sys.stderr)

    write_cards_to_h5p(args.h5p_file, cards, args.title)
    print(f"Wrote {len(cards)} cards into {args.h5p_file}.", file=sys.stderr)
    return cards


if __name__ == "__main__":
    main()
