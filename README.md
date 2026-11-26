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
| `eleventy, bare` | Eleventy with a Nunjucks layout, the footnote plugin, and no highlighting plugin |
| `astro, bare, highlighting off` | Astro with a content collection, one page route, no integrations, and `syntaxHighlight: false` |
| `starlight, defaults` | Starlight with its defaults, so its theme, scripts, search index and highlighting are all included |
| `jekyll, bare, highlighting off` | Jekyll with a one-file layout, kramdown, and highlighting turned off |
| `mdbook, bare` | mdBook with a bare `index.hbs`, search and the print page off, and highlighting left to the browser |

The "highlighting off" cases compare like with like, since Reuben doesn't highlight code unless a site turns it on.
Eleventy, Astro, Starlight, Jekyll and mdBook build the same generated pages as the others.
They need a little translation: Hugo, Zola, Astro, and Jekyll read the front matter as it is, Eleventy gets the layout from a data file, and mdBook has no front matter, so `scripts/mdbook-src.mjs` strips it, writes the title as a heading, and lists every page in `SUMMARY.md`.
Starlight necessarily ships its theme, so its numbers show what a docs site costs by default, not a bare layout.
The one change to Starlight is a one-link sidebar, because the default sidebar lists every page on every page, which grows with the square of the page count and would not finish at 10,000 pages.
Astro and Starlight also write `.astro` and `node_modules/.astro` caches, which are deleted before every run with the output folder.
mdBook copies its theme files (CSS, JavaScript and fonts) into every build, so its byte count includes them.
There is no highlighting-on variant for these tools yet.

Each size runs every case interleaved in one [hyperfine](https://github.com/sharkdp/hyperfine) run, so background noise hits them all equally: 15 runs after 2 warm-ups, 5 runs at 10,000 pages.
The output folder is deleted before every run, so every build is a fresh one.

## Running it

You need Node, hyperfine, Hugo, Zola and a Reuben binary.
Eleventy, Astro, Starlight, Jekyll and mdBook are optional: `scripts/setup.sh` and `scripts/run.sh` skip any that isn't installed and say so, so a run with only Hugo and Zola still works.
Set `REQUIRE_TOOLS=1` to make a missing tool an error instead, as the workflow does.

The Node tools (Eleventy, Astro and Starlight) share one install at the exact versions in `tools/node/package.json`.
Run `npm ci` in `tools/node` once, and every case links to that `node_modules`, so no install ever runs inside a timed command.
Jekyll is found on your `PATH`, from the pinned `tools/ruby/Gemfile` (`bundle install` in `tools/ruby`), and runs without Bundler so Bundler's start-up isn't timed.
mdBook is found on your `PATH` too.
The tool versions are written to `results/latest/versions.txt`.
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
