// Turns a generated page set into an mdBook src/ folder: front matter removed, the title as a `# ` heading,
// and a flat SUMMARY.md, because mdBook has no front matter and builds only the pages SUMMARY.md lists.
//   node mdbook-src.mjs <setdir> <srcdir>
import fs from 'node:fs'; import path from 'node:path';
const [set, out] = process.argv.slice(2);
fs.rmSync(out, { recursive: true, force: true });
const pages = [];
const walk = (d) => {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.md')) pages.push(path.relative(path.join(set, 'content'), p));
  }
};
walk(path.join(set, 'content'));
pages.sort((a, b) => (a === 'index.md' ? -1 : b === 'index.md' ? 1 : a.localeCompare(b)));
let summary = '# Summary\n\n';
for (const rel of pages) {
  const src = fs.readFileSync(path.join(set, 'content', rel), 'utf8');
  const m = src.match(/^---\n([\s\S]*?)\n---\n/);
  const title = m ? m[1].match(/^title: (.*)$/m)[1] : rel;
  const dst = path.join(out, rel);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.writeFileSync(dst, `# ${title}\n${m ? src.slice(m[0].length) : src}`);
  summary += `- [${title}](${rel})\n`;
}
fs.writeFileSync(path.join(out, 'SUMMARY.md'), summary);
fs.cpSync(path.join(set, 'static'), out, { recursive: true });
