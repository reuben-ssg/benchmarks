# Reuben benchmarks

How long [Reuben](https://github.com/reuben-ssg/reuben) takes to build the same Markdown site as other static site generators, how much memory it uses, and how heavy the pages it writes are.

Every tool builds the same generated pages with a bare layout: a title, the page content, and nothing else.
Each page has headings, lists, links, a footnote, a table and one Rust code block.

## What gets measured

| Case | What it is |
| --- | --- |
| `reuben, bare` | Reuben with its defaults: no highlighting, no math, no sitemap, every check off |
| `reuben, bare, footnote back-links off` | The same, with `[markdown] footnote_backlinks = false` (turns off an accessibility feature) |
| `reuben, bare + checks` | Reuben with every accessibility and link check on |
| `hugo, bare, highlighting on` / `off` | Hugo with its default code highlighting, and with `codeFences = false` |
| `zola, bare, highlighting on` / `off` | Zola with a highlighting theme, and without one |

The "highlighting off" cases compare like with like, since Reuben doesn't highlight code unless a site turns it on.
Each size runs every case interleaved in one [hyperfine](https://github.com/sharkdp/hyperfine) run, so background noise hits them all equally: 15 runs after 2 warm-ups, 5 runs at 10,000 pages.
The output folder is deleted before every run, so every build is a fresh one.

## Running it

You need Node, hyperfine, Hugo, Zola and a Reuben binary.
The scripts are written for macOS: they read the load average and power source to wait for a quiet machine.

```sh
scripts/setup.sh                      # generates sets/ and cases/ for 10, 50, 1,000 and 10,000 pages
REUBEN=$(command -v reuben) scripts/run.sh
```

`scripts/run.sh 1000` runs one size.
Set `BASELINE` to a second Reuben binary to time it alongside, for before-and-after comparisons.
Each run writes `results/latest/`, including the tool versions and machine load; copy it into `results/<date>/` to keep it.

## Results

`results/2026-11-20/` is the first run made with these scripts: the lean spike against Hugo and Zola.
`results/2026-11-19/` holds the runs before this repository existed:

- `hugo-zola.md`: Reuben 0.1.1 against Hugo and Zola.
- `astro-starlight.md`: Reuben 0.1.1 against Astro and Starlight.
- `lean-investigation.md`: where Reuben's time, memory and bytes went, and what to change.
- `lean-spike.md`: an unreleased build with those changes, against Hugo and Zola.

These runs were made with scripts that this repository's scripts were cleaned up from, so file paths inside them point at the original scratch folders.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
