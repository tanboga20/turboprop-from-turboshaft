"""Bar chart of the compliance verdicts at the PDR and at the CDR, in English and Turkish.

    python requirements/plot_compliance.py [out_dir]        (needs matplotlib)

Writes compliance_en.png and compliance_tr.png (default: calc/results/step211). Source: Phase 2 report,
Section 2.11.
"""
import csv
import sys
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).parent
VERDICTS = ("met", "partial", "risk", "open", "tbd")
LABELS = {"en": {"met": "met", "partial": "partial", "risk": "risk", "open": "open", "tbd": "TBD (supplier value)",
                 "title": "Requirement compliance: PDR (v2, 65) and CDR (v3, 66)", "y": "Requirements"},
          "tr": {"met": "sağlanıyor", "partial": "kısmen", "risk": "risk", "open": "açık", "tbd": "TBD (tedarikçi değeri)",
                 "title": "Gereksinim uyumu: PDR (v2, 65) ve CDR (v3, 66)", "y": "Gereksinim sayısı"}}
COLOURS = {"met": "#2e7d32", "partial": "#f9a825", "risk": "#c62828", "open": "#1565c0", "tbd": "#9e9e9e"}


def counts(name):
    with open(HERE / name, encoding="utf-8", newline="") as f:
        return Counter(r["verdict"] for r in csv.DictReader(f))


def main(out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    pdr, cdr = counts("compliance_pdr.csv"), counts("compliance_cdr.csv")
    for lang, lab in LABELS.items():
        fig, ax = plt.subplots(figsize=(8.5, 3.6))
        shown = set()
        for row, (name, c) in enumerate((("PDR", pdr), ("CDR", cdr))):
            left = 0
            for v in VERDICTS:
                if c[v]:
                    ax.barh(row, c[v], left=left, color=COLOURS[v], edgecolor="white",
                            label=None if v in shown else lab[v])
                    shown.add(v)
                    ax.text(left + c[v] / 2, row, str(c[v]), ha="center", va="center", color="white", fontsize=10,
                            fontweight="bold")
                    left += c[v]
        ax.set_yticks([0, 1])
        ax.set_yticklabels(["PDR", "CDR"])
        ax.invert_yaxis()
        ax.set_xlabel(lab["y"])
        ax.set_title(lab["title"], fontsize=11)
        ax.legend(ncol=5, loc="upper center", bbox_to_anchor=(0.5, -0.25), frameon=False, fontsize=9)
        ax.spines[["top", "right"]].set_visible(False)
        fig.tight_layout()
        fig.savefig(out_dir / f"compliance_{lang}.png", dpi=150)
        plt.close(fig)
    print(f"PDR {dict(pdr)}, CDR {dict(cdr)} -> {out_dir}")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "calc" / "results" / "step211")
