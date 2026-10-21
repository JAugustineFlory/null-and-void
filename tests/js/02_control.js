for (let i = 0; i < 5; i++) {
  if (i === 1) continue;
  if (i === 4) break;
  console.log("for", i);
}
let n = 3;
while (n > 0) {
  console.log("while", n);
  n--;
}
for (const c of "abc") console.log(c);
for (const x of [10, 20, 30]) {
  if (x === 20) continue;
  console.log("of", x);
}
for (const row of [[1, 2], [3, 4]]) {
  for (const v of row) {
    if (v === 2) break;
    console.log("v", v);
  }
}
let k = 0;
for (;;) { k++; if (k > 3) break; }
console.log("k", k);
if (k > 10) console.log("big"); else if (k > 2) console.log("medium"); else console.log("small");
