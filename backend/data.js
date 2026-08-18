const inventory = [
  { productId: 'p1', name: 'Widget A', available: 50, reorderThreshold: 10 },
  { productId: 'p2', name: 'Widget B', available: 20, reorderThreshold: 5 },
  { productId: 'p3', name: 'Widget C', available: 5, reorderThreshold: 5 }
];

let backorders = [];
let backorderCounter = 1;
let notifications = [];
let analyticsHistory = [];

const orders = [
  {
    orderId: 'o1',
    priority: 3,
    createdAt: Date.now() - 1000 * 60 * 60,
    items: [{ productId: 'p1', qty: 10 }, { productId: 'p3', qty: 2 }],
    status: 'created',
    allocated: {},
    picked: false,
    packed: false,
    dispatched: false
  },
  {
    orderId: 'o2',
    priority: 1,
    createdAt: Date.now() - 1000 * 60 * 30,
    items: [{ productId: 'p1', qty: 5 }],
    status: 'created',
    allocated: {},
    picked: false,
    packed: false,
    dispatched: false
  },
  {
    orderId: 'o3',
    priority: 2,
    createdAt: Date.now() - 1000 * 60 * 10,
    items: [{ productId: 'p2', qty: 15 }],
    status: 'created',
    allocated: {},
    picked: false,
    packed: false,
    dispatched: false
  }
];

function getInventory() {
  return inventory;
}

function getOrders() {
  return orders;
}

function findInv(productId) {
  return inventory.find((p) => p.productId === productId);
}

function allocateAll() {
  // reset allocations fields if missing
  orders.forEach((o) => {
    o.allocated = o.allocated || {};
    o.status = o.status || 'created';
  });

  const avail = {};
  inventory.forEach((p) => (avail[p.productId] = p.available));

  const sorted = [...orders].sort((a, b) => {
    if (b.priority !== a.priority) return b.priority - a.priority;
    return a.createdAt - b.createdAt;
  });

  sorted.forEach((order) => {
    order.allocated = {};
    order.items.forEach((it) => {
      const need = it.qty;
      const have = avail[it.productId] || 0;
      const take = Math.min(need, have);
      order.allocated[it.productId] = take;
      avail[it.productId] = have - take;
    });
  });

  // try to reassign from lower-priority orders to satisfy higher-priority
  for (let i = 0; i < sorted.length; i++) {
    const order = sorted[i];
    order.items.forEach((it) => {
      let needed = it.qty - (order.allocated[it.productId] || 0);
      if (needed <= 0) return;
      for (let j = sorted.length - 1; j > i && needed > 0; j--) {
        const other = sorted[j];
        if (other.priority >= order.priority) continue;
        const otherAlloc = other.allocated[it.productId] || 0;
        if (otherAlloc <= 0) continue;
        const steal = Math.min(otherAlloc, needed);
        other.allocated[it.productId] = otherAlloc - steal;
        order.allocated[it.productId] = (order.allocated[it.productId] || 0) + steal;
        needed -= steal;
      }
    });
  }

  sorted.forEach((order) => {
    let fully = true;
    order.items.forEach((it) => {
      if ((order.allocated[it.productId] || 0) < it.qty) fully = false;
    });
    order.status = fully ? 'allocated' : 'partial';
    // mark when allocation ran
    order.allocatedAt = Date.now();
  });

  // commit available quantities
  inventory.forEach((p) => {
    p.available = avail[p.productId];
  });

  // compute backorders
  backorders = [];
  sorted.forEach((order) => {
    order.items.forEach((it) => {
      const short = it.qty - (order.allocated[it.productId] || 0);
      if (short > 0) {
        backorders.push({ id: 'b' + (backorderCounter++), orderId: order.orderId, productId: it.productId, qty: short, createdAt: Date.now() });
      }
    });
  });

  return { orders: sorted, inventory, backorders };
}

function pushAnalyticsSnapshot() {
  try {
    const a = analytics();
    analyticsHistory.push({ ts: Date.now(), ...a });
    if (analyticsHistory.length > 200) analyticsHistory.shift();
  } catch (e) {
    // ignore
  }
}

function createOrder(order) {
  orders.push({ ...order, status: 'created', allocated: {}, picked: false, pickedItems: {}, packed: false, dispatched: false, createdAt: Date.now() });
}

function pickOrder(orderId) {
  const o = orders.find((x) => x.orderId === orderId);
  if (!o) return { error: 'order not found' };
  // mark picked for allocated quantities
  o.picked = true;
  // mark all allocated as picked
  o.pickedItems = o.pickedItems || {};
  o.items.forEach(it => {
    o.pickedItems[it.productId] = o.allocated[it.productId] || 0;
  });
  if (o.status === 'allocated' || o.status === 'partial') o.status = 'picked';
  return o;
}

function pickItem(orderId, productId, qty) {
  const o = orders.find((x) => x.orderId === orderId);
  if (!o) return { error: 'order not found' };
  o.pickedItems = o.pickedItems || {};
  const already = o.pickedItems[productId] || 0;
  const alloc = o.allocated[productId] || 0;
  const toPick = Math.min(qty, alloc - already);
  if (toPick <= 0) return { error: 'nothing to pick' };
  o.pickedItems[productId] = already + toPick;
  // if all items picked, mark order picked
  let allPicked = true;
  o.items.forEach(it => {
    if ((o.pickedItems[it.productId] || 0) < (o.allocated[it.productId] || 0)) allPicked = false;
  });
  if (allPicked) o.picked = true;
  if (allPicked && !o.pickedAt) o.pickedAt = Date.now();
  o.status = allPicked ? 'picked' : 'partial-pick';
  return { ok: true, order: o };
}

function packOrder(orderId) {
  const o = orders.find((x) => x.orderId === orderId);
  if (!o) return { error: 'order not found' };
  if (!o.picked) return { error: 'order not picked yet' };
  o.packed = true;
  o.status = 'packed';
  if (!o.packedAt) o.packedAt = Date.now();
  return o;
}

function dispatchOrder(orderId) {
  const o = orders.find((x) => x.orderId === orderId);
  if (!o) return { error: 'order not found' };
  if (!o.packed) return { error: 'order not packed yet' };
  o.dispatched = true;
  o.status = 'dispatched';
  if (!o.dispatchedAt) o.dispatchedAt = Date.now();
  // clear allocations (finalized)
  o.allocated = {};
  // push analytics snapshot when dispatch happens
  try { pushAnalyticsSnapshot(); } catch (e) {}
  return o;
}

function damageItem(orderId, productId, qty) {
  const o = orders.find((x) => x.orderId === orderId);
  const inv = findInv(productId);
  if (!o || !inv) return { error: 'order or product not found' };
  const allocated = o.allocated[productId] || 0;
  const damaged = Math.min(allocated, qty);
  // remove damaged from allocation (damaged not returned to stock)
  o.allocated[productId] = Math.max(0, allocated - damaged);
  // set exception status on the order
  o.status = 'exception';

  return { order: o, damaged };
}

function getState() {
  return { inventory, orders, backorders };
}

function reportStats() {
  const counts = orders.reduce(
    (acc, o) => {
      acc[o.status] = (acc[o.status] || 0) + 1;
      return acc;
    },
    {}
  );
  const lowStock = inventory.filter((p) => p.available <= p.reorderThreshold);
  const bottlenecks = orders.filter((o) => (Date.now() - o.createdAt) > 1000 * 60 * 30 && o.status !== 'dispatched');
  return { counts, lowStock, bottlenecks, backorders };
}

function analytics() {
  const dispatched = orders.filter(o => o.dispatched && o.dispatchedAt && o.createdAt);
  const avgFulfillmentMs = dispatched.length ? Math.round(dispatched.reduce((s,o)=>s + (o.dispatchedAt - o.createdAt),0)/dispatched.length) : 0;
  const avgPickMs = orders.filter(o=>o.pickedAt && o.allocatedAt).length ? Math.round(orders.filter(o=>o.pickedAt && o.allocatedAt).reduce((s,o)=>s + (o.pickedAt - o.allocatedAt),0) / orders.filter(o=>o.pickedAt && o.allocatedAt).length) : 0;
  const avgPackMs = orders.filter(o=>o.packedAt && o.pickedAt).length ? Math.round(orders.filter(o=>o.packedAt && o.pickedAt).reduce((s,o)=>s + (o.packedAt - o.pickedAt),0) / orders.filter(o=>o.packedAt && o.pickedAt).length) : 0;
  const orderAges = orders.map(o => ({ orderId: o.orderId, ageMinutes: Math.round((Date.now() - o.createdAt)/60000), status: o.status }));
  const topDelays = orderAges.filter(o=>o.status !== 'dispatched').sort((a,b)=>b.ageMinutes - a.ageMinutes).slice(0,10);
  const inventoryTurnover = inventory.map(p=>({ productId: p.productId, available: p.available, reorderThreshold: p.reorderThreshold }));
  return { avgFulfillmentMs, avgPickMs, avgPackMs, orderAges, topDelays, inventoryTurnover };
}

function getAnalyticsHistory() {
  return analyticsHistory;
}

function clearAnalyticsHistory() {
  analyticsHistory = [];
  return { ok: true };
}

function prioritizeBackorders() {
  return backorders
    .map(b => {
      const order = orders.find(o => o.orderId === b.orderId) || {};
      const priority = order.priority || 0;
      const ageMin = Math.round((Date.now() - b.createdAt) / 60000);
      return { ...b, priority, orderCreatedAt: order.createdAt, ageMin };
    })
    .sort((a, b) => {
      if (b.priority !== a.priority) return b.priority - a.priority;
      return b.ageMin - a.ageMin;
    });
}

function simulateNotify(target, message) {
  const note = { id: 'n' + Date.now(), to: target, message, timestamp: Date.now() };
  notifications.unshift(note);
  // keep last 100
  if (notifications.length > 100) notifications.pop();
  return note;
}

function getNotifications() {
  return notifications;
}

function clearNotifications() {
  notifications = [];
  return { ok: true };
}

function getBackorders() {
  return backorders;
}

function resolveBackorder(backorderId, qty) {
  const idx = backorders.findIndex((b) => b.id === backorderId);
  if (idx === -1) return { error: 'backorder not found' };
  const b = backorders[idx];
  const inv = findInv(b.productId);
  if (!inv) return { error: 'product not found' };
  // receive qty into inventory and reduce backorder
  inv.available += qty;
  b.qty = Math.max(0, b.qty - qty);
  if (b.qty === 0) backorders.splice(idx, 1);
  return { ok: true, backorder: b };
}

function placeReorder(productId, qty) {
  const inv = findInv(productId);
  if (!inv) return { error: 'product not found' };
  inv.available += qty;
  return { ok: true, product: inv };
}

module.exports = {
  getInventory,
  getOrders,
  allocateAll,
  createOrder,
  pickOrder,
  packOrder,
  dispatchOrder,
  damageItem,
  getState,
  reportStats
  getBackorders,
  resolveBackorder,
  placeReorder,
  analytics,
  prioritizeBackorders
  simulateNotify,
  getNotifications,
  clearNotifications
  ,getAnalyticsHistory, clearAnalyticsHistory
};
