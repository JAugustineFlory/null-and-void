// Each pass of a loop gets its own variable when a function keeps hold of it.
const later = [];
for (let i = 0; i < 3; i++) {
  later.push(() => i);
}
console.log(later.map(f => f()));
const names = [];
for (const door of ["D-1", "D-2", "D-3"]) {
  names.push(() => door);
  if (door === "D-2") continue;
}
console.log(names.map(f => f()));
const blocks = [];
let n = 0;
while (n < 3) {
  const copy = n * 10;
  blocks.push(() => copy);
  n++;
}
console.log(blocks.map(f => f()));
for (let i = 0; i < 5; i++) {
  const keep = () => i;
  if (i === 1) continue;
  if (i === 3) break;
  console.log("pass", i, keep());
}
for (const x of [1, 2, 3]) {
  const f = () => x * 2;
  if (x === 2) break;
  console.log("of", f());
}
function makeCounters() {
  const out = [];
  for (let i = 0; i < 2; i++) {
    let count = i * 100;
    out.push(() => ++count);
  }
  return out;
}
const counters = makeCounters();
const a = counters[0];
const b = counters[1];
console.log(a(), a(), b());
