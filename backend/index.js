const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { getInventory, getOrders, allocateAll, createOrder, pickOrder, pickItem, packOrder, dispatchOrder, damageItem, getState, reportStats, analytics, prioritizeBackorders, simulateNotify } = require('./data');
const { getBackorders, resolveBackorder, placeReorder, getAnalyticsHistory, clearAnalyticsHistory } = require('./data');
const { getNotifications, clearNotifications } = require('./data');

const app = express();
app.use(cors());
app.use(bodyParser.json());

app.get('/api/inventory', (req, res) => {
  res.json(getInventory());
});

app.get('/api/orders', (req, res) => {
  res.json(getOrders());
});

app.post('/api/allocate', (req, res) => {
  const result = allocateAll();
  res.json(result);
});

app.post('/api/order', (req, res) => {
  const { order } = req.body;
  if (!order || !order.orderId) return res.status(400).json({ error: 'order required' });
  createOrder(order);
  res.json({ ok: true });
});

app.get('/api/state', (req, res) => {
  res.json(getState());
});

app.post('/api/pick/:orderId', (req, res) => {
  const { orderId } = req.params;
  const out = pickOrder(orderId);
  if (out.error) return res.status(400).json(out);
  res.json(out);
});

app.post('/api/pick-item/:orderId', (req, res) => {
  const { orderId } = req.params;
  const { productId, qty } = req.body;
  const out = pickItem(orderId, productId, qty || 0);
  if (out.error) return res.status(400).json(out);
  res.json(out);
});

app.post('/api/pack/:orderId', (req, res) => {
  const { orderId } = req.params;
  const out = packOrder(orderId);
  if (out.error) return res.status(400).json(out);
  res.json(out);
});

app.post('/api/dispatch/:orderId', (req, res) => {
  const { orderId } = req.params;
  const out = dispatchOrder(orderId);
  if (out.error) return res.status(400).json(out);
  res.json(out);
});

app.post('/api/damage', (req, res) => {
  const { orderId, productId, qty, autoResolve } = req.body;
  const out = damageItem(orderId, productId, qty || 0);
  if (out.error) return res.status(400).json(out);
  // optional auto-resolve: re-run allocation to attempt reassignments
  if (autoResolve) {
    const alloc = allocateAll();
    const suggestions = alloc.inventory.filter(p => p.available <= p.reorderThreshold).map(p=>({ productId: p.productId, available: p.available, reorderThreshold: p.reorderThreshold }));
    return res.json({ damage: out, allocation: alloc, suggestions });
  }
  res.json(out);
});

app.get('/api/report', (req, res) => {
  res.json(reportStats());
});

app.get('/api/analytics', (req, res) => {
  res.json(analytics());
});

app.get('/api/backorders', (req, res) => {
  res.json(getBackorders());
});

app.get('/api/backorder-priority', (req, res) => {
  res.json(prioritizeBackorders());
});

app.post('/api/notify', (req, res) => {
  const { target, message } = req.body;
  const out = simulateNotify(target, message);
  res.json(out);
});

app.get('/api/notifications', (req, res) => {
  res.json(getNotifications());
});

app.post('/api/notifications/clear', (req, res) => {
  res.json(clearNotifications());
});

app.get('/api/analytics-history', (req, res) => {
  res.json(getAnalyticsHistory());
});

app.post('/api/analytics-history/clear', (req, res) => {
  res.json(clearAnalyticsHistory());
});

app.post('/api/resolve-backorder', (req, res) => {
  const { backorderId, qty } = req.body;
  const out = resolveBackorder(backorderId, qty || 0);
  if (out.error) return res.status(400).json(out);
  res.json(out);
});

app.post('/api/reorder', (req, res) => {
  const { productId, qty } = req.body;
  const out = placeReorder(productId, qty || 0);
  if (out.error) return res.status(400).json(out);
  res.json(out);
});

const port = process.env.PORT || 4000;
app.listen(port, () => console.log(`Backend running on http://localhost:${port}`));
