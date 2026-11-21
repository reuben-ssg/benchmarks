# 2026-11-21: Reuben lean branch against Hugo and Zola

The acceptance run for Reuben's lean milestone, on AC power with the machine quiet (see `conditions-*.txt`).

- `reuben` is the `lean` branch of reuben-ssg/reuben at `597b8e0`, the work planned for 0.2.0. It still reports its version as 0.1.1.
- `reuben baseline` is the released 0.1.1. Its output bytes match `../2026-11-20/bytes.txt`; the table can't show them because both builds share a case folder.

At 1,000 pages, bare layout, median of 15 interleaved runs:

| Tool | Time | Peak memory | Output |
| --- | --- | --- | --- |
| Reuben 0.1.1 | 219.2 ms | 57 MiB | 3,863,109 bytes |
| Reuben lean | 73.7 ms | 28 MiB | 1,794,109 bytes |
| Reuben lean, footnote back-links off | 96.7 ms (fastest 71.6) | 28 MiB | 1,734,109 bytes |
| Reuben lean, every check on | 104.3 ms | 30 MiB | 1,794,109 bytes |
| Zola, highlighting off | 88.0 ms | 52 MiB | 1,749,177 bytes |
| Hugo, highlighting off | 140.3 ms | 149 MiB | 1,932,757 bytes |
| Zola, highlighting on | 201.1 ms | 89 MiB | 2,271,177 bytes |
| Hugo, highlighting on | 154.5 ms | 183 MiB | 2,614,757 bytes |

The back-links-off median includes one slow run; its fastest run matches the default.
At 10,000 pages Reuben took 691 ms against Zola's 745 ms and Hugo's 1,088 ms (highlighting off), with 133 MiB against 253 and 804.
