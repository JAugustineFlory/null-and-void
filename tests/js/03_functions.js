function add(a, b) { return a + b; }
const mul = (a, b) => a * b;
const sq = x => x * x;
const hello = function () { return "hi"; };
console.log(add(2, 3), mul(4, 5), sq(6), hello(), add(1), add("a", "b"));
console.log(early(2));
function early(x) { return x * 10; }
function counter() {
  let count = 0;
  return () => { count++; return count; };
}
const c1 = counter();
const c2 = counter();
c1(); c1();
console.log(c1(), c2());
function fact(n) { return n <= 1 ? 1 : n * fact(n - 1); }
console.log(fact(10));
const ops = { double: x => x * 2, triple(x) { return x * 3; } };
console.log(ops.double(4), ops.triple(4));
console.log(add, sq, ops);
function noReturn() {}
console.log(noReturn());
