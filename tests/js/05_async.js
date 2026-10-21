console.log("start");
await sleep(100);
console.log("after 100");
async function blink(name, times) {
  for (let i = 0; i < times; i++) {
    console.log(name, i);
    await sleep(50);
  }
  return name + " done";
}
const p = blink("A", 3);
console.log("started A");
const r = await blink("B", 2);
console.log(r);
console.log(await p);
const v = await 5;
console.log(v);
