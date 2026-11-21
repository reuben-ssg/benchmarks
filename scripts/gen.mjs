// Generates a benchmark page set: N Markdown pages with headings, lists, links, a footnote, a table and a Rust block.
//   node gen.mjs <N> <outdir> [--math-text] [--no-code] [--no-math] [--empty]
// --math-text: write the formula as `\$x\$`, which every tool renders as the same plain text.
// --empty: content/ with only the home page (0 generated pages).
import fs from 'node:fs'; import path from 'node:path';
const [N0, out, ...flags] = process.argv.slice(2); const N = +N0;
const mathText = flags.includes('--math-text');
const noCode = flags.includes('--no-code'), noMath = flags.includes('--no-math'), empty = flags.includes('--empty');
const w = (p, t) => { fs.mkdirSync(path.dirname(p), {recursive:true}); fs.writeFileSync(p, t); };
const C = ['guides','notes','posts','refs'];
const pid = i => 'p' + String(i).padStart(5,'0');
const d = out; fs.rmSync(d, {recursive:true, force:true});
w(path.join(d,'static/img/logo.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="#c60"/></svg>\n');
w(path.join(d,'content/index.md'), `---\ntitle: Bench home\ndescription: Home of the ${N}-page benchmark set.\n---\n\nStart with [the first page](/guides/${pid(0)}/).\n`);
for (let i = 0; i < (empty ? 0 : N); i++) {
  const name = C[i % 4], extra = 3 + i % 3;
  const nxt = i + 4 < N ? `/${name}/${pid(i+4)}/` : '/';
  let b = `---\ntitle: Page ${i}\ndescription: Generated page ${i} in ${name}.\nweight: ${i}\n---\n\n`;
  for (let h = 0; h < extra; h++) b += `## Section ${h}\n\nProse for page ${i}, section ${h}, with *emphasis* and a [link to the next page](${nxt}) and an [anchor link](${nxt}${nxt==='/'?'':'#section-1'}).\n\n- item one\n- item two with \`code\`\n\n`;
  b += mathText ? `Inline math \\$x^{${i}} + y\\$ and a note.[^1]\n\n` : noMath ? `Inline text and a note.[^1]\n\n` : `Inline math $x^{${i}} + y$ and a note.[^1]\n\n`;
  if (i % 10 === 0) b += `![Bench logo](/img/logo.svg)\n\n`;
  if (i % 10 === 7) b += `![](/img/logo.svg)\n\n`;
  if (i >= 1 && i <= 3) b += `A [broken link](/missing/nope-${i}/) here.\n\n`;
  if (i === 4 || i === 5) b += `A [bad anchor](/guides/${pid(0)}/#no-such-anchor-${i}) here.\n\n`;
  if (!noCode) b += `\`\`\`rust\nfn main() {\n    let n = ${i};\n    println!("{}", n);\n}\n\`\`\`\n\n`;
  b += `| Key | Value |\n| --- | --- |\n| id | ${i} |\n| group | ${name} |\n\n[^1]: Footnote text for page ${i}.\n`;
  w(path.join(d,'content',name,pid(i)+'.md'), b);
}
