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
On macOS the scripts read the load average and power source to wait for a quiet machine; on Linux they check only the load, and `QUIET=0` skips the wait.

```sh
scripts/setup.sh                      # generates sets/ and cases/ for 10, 50, 1,000 and 10,000 pages
REUBEN=$(command -v reuben) scripts/run.sh
```

`scripts/run.sh 1000` runs one size.
Set `BASELINE` to a second Reuben binary to time it alongside, for before-and-after comparisons.
Each run writes `results/latest/`, including the tool versions and machine load; copy it into `results/<date>/` to keep it.

## Running on GitHub Actions

The `bench` workflow runs the benchmarks on an `ubuntu-24.04` runner, so a run doesn't need your laptop.
Start it from the Actions tab, or with the GitHub CLI:

```sh
gh workflow run bench.yml -f reuben_ref=my-branch -f baseline_ref=main
```

The inputs are `reuben_ref` (default `main`), `baseline_ref` (default none), `sizes` (default `"1000 10000"`), and `hash_case` (time Reuben with asset hashing on).
The results land in the run's summary, and `results/latest` is uploaded as the `bench-<run id>` artifact.

Shared runners are noisier than a quiet laptop, and they are a different machine, so their absolute numbers aren't comparable to the published macOS results.
What CI runs are good for is the interleaved before-and-after comparison: set `baseline_ref`, and both builds are timed in the same hyperfine run on the same runner.
Changes to `scripts/` or the workflow also run a size-50 smoke test on pull requests.

## Profiling on GitHub Actions

The `profile` workflow shows where Reuben's CPU time goes on Linux, next to Zola's.
It builds Reuben and Zola with symbols and frame pointers, then runs each single-threaded under `perf stat`, `strace -c`, and `perf record`.
Start it from the Actions tab, or with the GitHub CLI:

```sh
gh workflow run profile.yml -f reuben_ref=my-branch -f size=10000
```

The inputs are `reuben_ref` (default `main`), `size` (default `10000`), and `zola_version` (default `0.23.6`).
It also times Reuben at `--jobs 1`, `2`, and `4`, and with no `--jobs` flag, to see how threads change the CPU time.
The summary shows the counters, the top self-time symbols, and the syscall counts.
The `profile-<run id>` artifact holds the full reports and a flame graph (`.svg`) per tool.

## Results

`results/2026-11-21/` is the Reuben lean branch, the work planned for 0.2.0, against Hugo and Zola.
`results/2026-11-20/` is the first run made with these scripts: the lean spike against Hugo and Zola.
`results/2026-11-19/` holds the runs before this repository existed:

- `hugo-zola.md`: Reuben 0.1.1 against Hugo and Zola.
- `astro-starlight.md`: Reuben 0.1.1 against Astro and Starlight.
- `lean-investigation.md`: where Reuben's time, memory and bytes went, and what to change.
- `lean-spike.md`: an unreleased build with those changes, against Hugo and Zola.

These runs were made with scripts that this repository's scripts were cleaned up from, so file paths inside them point at the original scratch folders.

Made with love by [@nickvigilante](https://github.com/nickvigilante).

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
