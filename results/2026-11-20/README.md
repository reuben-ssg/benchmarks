# 2026-11-20: lean spike against Hugo and Zola

The first run made with this repository's own scripts, on AC power with the machine quiet (see `conditions-*.txt`).

- `reuben` is an unreleased build of the lean spike: highlighting, math and the sitemap off by default, parallel reads, pages written as they render.
  It still reports its version as 0.1.1, as `versions.txt` shows.
- `reuben baseline` is the released 0.1.1.
- `table.md` holds every size; `bytes.txt` adds the baseline's output size, which the table can't show because both builds share a case folder.

At 1,000 pages, bare layout, median of 15 interleaved runs:

| Tool | Time | Peak memory | Output |
| --- | --- | --- | --- |
| Reuben 0.1.1 | 214.5 ms | 56 MiB | 3,863,109 bytes |
| Reuben lean spike | 77.0 ms | 28 MiB | 1,794,109 bytes |
| Reuben lean spike, footnote back-links off | 77.2 ms | 28 MiB | 1,734,109 bytes |
| Zola, highlighting off | 87.1 ms | 52 MiB | 1,749,177 bytes |
| Hugo, highlighting off | 134.5 ms | 148 MiB | 1,932,757 bytes |
| Zola, highlighting on | 197.9 ms | 90 MiB | 2,271,177 bytes |
| Hugo, highlighting on | 163.1 ms | 182 MiB | 2,614,757 bytes |

At 10,000 pages the spike took 677 ms against Zola's 754 ms and Hugo's 1,076 ms (highlighting off), with 134 MiB against 252 and 822.
With every check on, it built 1,000 pages in 105 ms, faster than Hugo with no checks.

The only place Zola writes fewer bytes is footnotes: it has no link from a footnote back to its reference, and Reuben does, for screen-reader and keyboard users.
