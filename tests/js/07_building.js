// The building's api and db (not in Node, so 07_building.out was checked by hand).
const doors = await db.query("SELECT id, locked FROM doors ORDER BY id");
console.log(doors.length, doors[0].id, doors[0].locked);
const zoneC = await db.query("SELECT id FROM doors WHERE zone = ? AND locked = ?", ["C", 1]);
console.log(zoneC.map(d => d.id).join(","));
let res = await api.get("/doors/D-12");
console.log(res.status, res.body.locked);
res = await api.patch("/doors/D-12", { locked: false });
console.log(res.status, res.body.error);
res = await api.patch("/doors/D-12", { locked: false }, { "X-Api-Key": "7f3a-22" });
console.log(res.status, res.body.locked);
res = await api.patch("/doors/D-12", { lockd: true }, { "X-Api-Key": "7f3a-22" });
console.log(res.status, res.body.error);
res = await api.get("/nowhere");
console.log(res.status, typeof res.body.error);
const pending = api.get("/doors/D-12");
console.log(typeof pending.status);
assert((await pending).status === 200, "the door should answer");
console.log("checked");
