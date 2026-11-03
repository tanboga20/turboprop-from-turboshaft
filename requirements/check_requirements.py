"""Check the requirement tables for consistency and print a summary.

Run from the repository root:

    python requirements/check_requirements.py        # the current version, v4
    python requirements/check_requirements.py v2     # an earlier version

Checks that IDs are unique, that every code is one of the allowed codes, and
that every need, assumption or requirement ID named in a text or source cell
exists. From v2 on it also checks the change column (v2_change to v4_change)
against the previous version: "new" rows must not be in it, "changed" rows
must differ from it, unmarked rows must be identical, and no ID may
disappear. For a version with a compliance matrix (v2: compliance_pdr.csv at
the preliminary design review, v3: compliance_cdr.csv at the critical design
review, v4: compliance_final.csv at the end of Phase 3) it checks that every requirement has exactly one row with a known
verdict and evidence in both languages. Exits with status 1 if anything is
wrong.
"""
import csv
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).parent
VERSIONS = ("v1", "v2", "v3", "v4")
CHANGES = ("new", "changed")
COMPLIANCE = {"v2": "compliance_pdr.csv", "v3": "compliance_cdr.csv", "v4": "compliance_final.csv"}
VERDICTS = ("met", "partial", "risk", "open", "tbd")
EVIDENCE = ("evidence_tr", "evidence_en")

GROUPS = {"SYS", "LD", "SAF", "DYN", "STR", "LUB", "ACC", "PIF", "CTL", "MNT", "ENV"}
CODES = {
    "source_type": {"cus", "crt", "ref", "acr", "asm"},
    "allocation": {"shf", "ger", "brg", "prs", "hsg", "lub", "acc", "pif", "sen"},
    "verification": {"A", "T", "I", "D"},
    "verification_phase": {"P1", "P2", "P3"},
}
TYPES = {"shall", "goal"}
STATUSES = ("Agreed", "TBR", "TBD")
REQUIRED_TEXT = ("title_tr", "title_en", "text_tr", "text_en", "source_tr", "source_en")
ID_PATTERN = re.compile(r"\b(?:N|A|" + "|".join(sorted(GROUPS)) + r")-\d{2}\b")


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def codes(cell):
    return [c for c in cell.split(";") if c]


def check(requirements, needs_assumptions):
    errors = []
    ids = [r["id"] for r in needs_assumptions + requirements]
    errors += [f"{i}: ID used {n} times" for i, n in Counter(ids).items() if n > 1]
    known = set(ids)

    for r in requirements:
        rid = r["id"]
        if r["group"] not in GROUPS or not rid.startswith(r["group"] + "-"):
            errors.append(f"{rid}: group {r['group']!r} does not match the ID")
        if r["type"] not in TYPES:
            errors.append(f"{rid}: unknown type {r['type']!r}")
        if r["status"] not in STATUSES:
            errors.append(f"{rid}: unknown status {r['status']!r}")
        for column, allowed in CODES.items():
            found = codes(r[column])
            if not found:
                errors.append(f"{rid}: {column} is empty")
            errors += [f"{rid}: unknown {column} code {c!r}" for c in found if c not in allowed]
        errors += [f"{rid}: {column} is empty" for column in REQUIRED_TEXT if not r[column].strip()]

        named = {column: set(ID_PATTERN.findall(r[column])) for column in REQUIRED_TEXT}
        if named["source_tr"] != named["source_en"]:
            errors.append(f"{rid}: Turkish and English sources name different IDs")
        for missing in sorted(set().union(*named.values()) - known):
            errors.append(f"{rid}: names {missing}, which does not exist")
    return errors


def check_changes(rows, old_rows, version, previous):
    """Check the change column of one table against the previous version."""
    errors = []
    column = f"{version}_change"
    old = {r["id"]: r for r in old_rows}
    for r in rows:
        rid, change = r["id"], r[column]
        same = rid in old and all(r[k] == v for k, v in old[rid].items() if not k.endswith("_change"))
        if change not in ("",) + CHANGES:
            errors.append(f"{rid}: unknown {column} {change!r}")
        elif change == "new" and rid in old:
            errors.append(f"{rid}: marked new but it is in {previous}")
        elif change == "changed" and (rid not in old or same):
            errors.append(f"{rid}: marked changed but it is not changed from {previous}")
        elif change == "" and not same:
            errors.append(f"{rid}: differs from {previous} but is not marked")
    errors += [f"{i}: in {previous} but missing" for i in sorted(set(old) - {r["id"] for r in rows})]
    return errors


def check_compliance(rows, requirements, known):
    """Check the compliance matrix: one row per requirement, known verdicts, evidence in both languages."""
    errors = []
    ids = [r["id"] for r in rows]
    required = {r["id"] for r in requirements}
    errors += [f"compliance: {i} listed {n} times" for i, n in Counter(ids).items() if n > 1]
    errors += [f"compliance: {i} has no row" for i in sorted(required - set(ids))]
    errors += [f"compliance: {i} is not a requirement" for i in sorted(set(ids) - required)]
    for r in rows:
        rid = r["id"]
        if r["verdict"] not in VERDICTS:
            errors.append(f"compliance: {rid}: unknown verdict {r['verdict']!r}")
        errors += [f"compliance: {rid}: {column} is empty" for column in EVIDENCE if not r[column].strip()]
        named = {column: set(ID_PATTERN.findall(r[column])) for column in EVIDENCE}
        if named["evidence_tr"] != named["evidence_en"]:
            errors.append(f"compliance: {rid}: Turkish and English evidence name different IDs")
        for missing in sorted(set().union(*named.values()) - known):
            errors.append(f"compliance: {rid}: names {missing}, which does not exist")
    return errors


def main(argv):
    version = argv[1] if len(argv) > 1 else VERSIONS[-1]
    if version not in VERSIONS:
        print(f"Unknown version {version!r}; use one of {', '.join(VERSIONS)}")
        return 1
    requirements = read(HERE / f"requirements_{version}.csv")
    needs_assumptions = read(HERE / f"needs_assumptions_{version}.csv")
    errors = check(requirements, needs_assumptions)
    previous = VERSIONS[VERSIONS.index(version) - 1] if version != VERSIONS[0] else None
    if previous:
        for rows, name in ((requirements, "requirements"), (needs_assumptions, "needs_assumptions")):
            errors += check_changes(rows, read(HERE / f"{name}_{previous}.csv"), version, previous)
    compliance = read(HERE / COMPLIANCE[version]) if version in COMPLIANCE else None
    if compliance is not None:
        known = {r["id"] for r in needs_assumptions + requirements}
        errors += check_compliance(compliance, requirements, known)
    if errors:
        print(f"{len(errors)} problem(s):")
        for e in errors:
            print("  " + e)
        return 1

    status = Counter(r["status"] for r in requirements)
    parts = Counter(p for r in requirements for p in codes(r["allocation"]))
    groups = {r["group"] for r in requirements}
    print(f"OK ({version}): {len(requirements)} requirements in {len(groups)} groups, "
          f"{len(needs_assumptions)} needs and assumptions")
    print("Status: " + ", ".join(f"{s} {status[s]}" for s in STATUSES))
    print("Requirements per part: " + ", ".join(f"{p} {n}" for p, n in parts.most_common()))
    if previous:
        column = f"{version}_change"
        for rows, name in ((requirements, "Requirements"), (needs_assumptions, "Needs and assumptions")):
            changes = Counter(r[column] for r in rows)
            print(f"{name} since {previous}: "
                  + ", ".join(f"{c} {changes[c]}" for c in CHANGES)
                  + " (" + ", ".join(r["id"] for r in rows if r[column]) + ")")
    if compliance is not None:
        verdicts = Counter(r["verdict"] for r in compliance)
        print(f"Compliance ({COMPLIANCE[version]}): " + ", ".join(f"{v} {verdicts[v]}" for v in VERDICTS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
