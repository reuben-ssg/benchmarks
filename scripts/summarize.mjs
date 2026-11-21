// Turns the hyperfine JSON in a results folder into Markdown tables, plus output bytes per case.
// Usage: node scripts/summarize.mjs <results-dir>
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
const median = (a) => {
  const s = [...a].sort((x, y) => x - y);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const bytes = (d) => {
  if (!fs.existsSync(d)) return 0;
  let n = 0;
  for (const e of fs.readdirSync(d, { withFileTypes: true, recursive: true })) {
    if (e.isFile() && e.name !== '.reuben-output') n += fs.statSync(path.join(e.parentPath, e.name)).size;
  }
  return n;
};
const outDir = (cmd) => {
  const m = cmd.match(/--(?:root|source) (\S+)/);
  return m ? path.join(m[1], cmd.startsWith('hugo') || cmd.startsWith('zola') ? 'public' : 'dist') : null;
};

const sizes = fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => parseInt(f)).sort((a, b) => a - b);
for (const n of sizes) {
  const j = JSON.parse(fs.readFileSync(path.join(dir, `${n}.json`)));
  console.log(`\n## ${n} pages\n\n| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |\n|---|---|---|---|---|---|`);
  for (const r of j.results) {
    const m = r.measurements;
    const wall = m.map((x) => x.time_wall_clock.value * 1000);
    const cpu = m.map((x) => (x.time_user.value + x.time_system.value) * 1000);
    const rss = m.map((x) => x.memory_peak_resident.value / 1048576);
    // The baseline builds the same case folder as the measured Reuben, so its output was overwritten.
    const out = r.name.startsWith('reuben baseline') ? null : outDir(r.command);
    console.log(`| ${r.name} | ${median(wall).toFixed(1)} | ${Math.min(...wall).toFixed(1)} | ${median(cpu).toFixed(0)} | ${Math.max(...rss).toFixed(0)} | ${out ? bytes(out).toLocaleString('en-US') : ''} |`);
  }
}
