#!/usr/bin/env python3
# stdlib only so nobody needs openpyxl just to unpack the atlas
# usage: xlsx_to_csv.py <workbook.xlsx> <sheet name> <out.csv>
# run with no sheet name to list sheets
import csv
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
RNS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def col_index(ref):
    letters = re.match(r"[A-Z]+", ref).group()
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n - 1


def sheet_paths(z):
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    targets = {r.get("Id"): r.get("Target") for r in rels}
    out = {}
    for s in wb.iter(NS + "sheet"):
        t = targets[s.get(RNS + "id")].lstrip("/")
        out[s.get("name")] = t if t.startswith("xl/") else "xl/" + t
    return out


def shared_strings(z):
    if "xl/sharedStrings.xml" not in z.namelist():
        return []
    strings = []
    for _, el in ET.iterparse(z.open("xl/sharedStrings.xml")):
        if el.tag == NS + "si":
            strings.append("".join(t.text or "" for t in el.iter(NS + "t")))
            el.clear()
    return strings


def main():
    z = zipfile.ZipFile(sys.argv[1])
    sheets = sheet_paths(z)
    if len(sys.argv) < 4:
        print("\n".join(sheets))
        return
    sst = shared_strings(z)
    with open(sys.argv[3], "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        width = None
        for _, el in ET.iterparse(z.open(sheets[sys.argv[2]])):
            if el.tag != NS + "row":
                continue
            vals = {}
            for c in el.iter(NS + "c"):
                t = c.get("t")
                if t == "inlineStr":
                    v = "".join(x.text or "" for x in c.iter(NS + "t"))
                else:
                    v = c.findtext(NS + "v")
                    if v is not None and t == "s":
                        v = sst[int(v)]
                vals[col_index(c.get("r"))] = v if v is not None else ""
            # header row sets the width, excel drops trailing empty cells
            if width is None:
                width = max(vals) + 1
            w.writerow([vals.get(i, "") for i in range(width)])
            el.clear()


if __name__ == "__main__":
    main()
