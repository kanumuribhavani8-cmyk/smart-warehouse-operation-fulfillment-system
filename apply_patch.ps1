# Apply updated python_backend files (writes app.py and CHANGELOG.md)
# Run with PowerShell (ExecutionPolicy Bypass if needed):
# powershell -ExecutionPolicy Bypass -File .\apply_patch.ps1

$base = "C:\Users\ADMIN\Desktop\samrt warehouse\python_backend"

$app = @"
from flask import Flask, jsonify, request
from flask_cors import CORS
import time
from pathlib import Path

# Avoid Flask auto package discovery (which uses pkgutil.get_loader)
# that can break on some newer Python runtimes. Set explicit paths.
BASE_DIR = Path(__file__).resolve().parent
STATIC_FOLDER = str(BASE_DIR.parent / 'frontend')
app = Flask(__name__, static_folder=STATIC_FOLDER, static_url_path='', instance_path=str(BASE_DIR))
CORS(app)


@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_frontend(path):
    # Serve static frontend files from ../frontend
    if path == '':
        return app.send_static_file('index.html')
    return app.send_static_file(path)

now = lambda: int(time.time() * 1000)

inventory = [
    { 'productId': 'p1', 'name': 'Widget A', 'available': 50, 'reorderThreshold': 10 },
    { 'productId': 'p2', 'name': 'Widget B', 'available': 20, 'reorderThreshold': 5 },
    { 'productId': 'p3', 'name': 'Widget C', 'available': 5, 'reorderThreshold': 5 }
]

orders = [
    {
        'orderId': 'o1',
        'priority': 3,
        'createdAt': now() - 1000 * 60 * 60,
        'items': [{'productId': 'p1', 'qty': 10}, {'productId': 'p3', 'qty': 2}],
        'status': 'created', 'allocated': {}, 'picked': False, 'pickedItems': {}, 'packed': False, 'dispatched': False
    },
    {
        'orderId': 'o2',
        'priority': 1,
        'createdAt': now() - 1000 * 60 * 30,
        'items': [{'productId': 'p1', 'qty': 5}],
        'status': 'created', 'allocated': {}, 'picked': False, 'pickedItems': {}, 'packed': False, 'dispatched': False
    },
    {
        'orderId': 'o3',
        'priority': 2,
        'createdAt': now() - 1000 * 60 * 10,
        'items': [{'productId': 'p2', 'qty': 15}],
        'status': 'created', 'allocated': {}, 'picked': False, 'pickedItems': {}, 'packed': False, 'dispatched': False
    }
]

backorders = []
backorder_counter = 1
notifications = []
analytics_history = []

# helpers

def find_inv(pid):
    for p in inventory:
        if p['productId'] == pid:
            return p
    return None

def get_inventory():
    return inventory

def get_orders():
    return orders

def allocate_all():
    global backorders, backorder_counter
    # working copy of avail
    avail = {p['productId']: p['available'] for p in inventory}
    sorted_orders = sorted(orders, key=lambda o: (-o['priority'], o['createdAt']))
    for o in sorted_orders:
        o['allocated'] = {}
        for it in o['items']:
            need = it['qty']
            have = avail.get(it['productId'], 0)
            take = min(need, have)
            o['allocated'][it['productId']] = take
            avail[it['productId']] = have - take
    # reassign from lower-priority if needed
    for i, order in enumerate(sorted_orders):
        for it in order['items']:
            needed = it['qty'] - (order['allocated'].get(it['productId'], 0))
            if needed <= 0:
                continue
            for j in range(len(sorted_orders)-1, i, -1):
                other = sorted_orders[j]
                if other['priority'] >= order['priority']:
                    continue
                other_alloc = other['allocated'].get(it['productId'], 0)
                if other_alloc <= 0:
                    continue
                steal = min(other_alloc, needed)
                other['allocated'][it['productId']] = other_alloc - steal
                order['allocated'][it['productId']] = order['allocated'].get(it['productId'], 0) + steal
                needed -= steal
                if needed <= 0:
                    break
    # set status
    for o in sorted_orders:
        fully = True
        for it in o['items']:
            if o['allocated'].get(it['productId'], 0) < it['qty']:
                fully = False
        o['status'] = 'allocated' if fully else 'partial'
        o['allocatedAt'] = now()
    # commit available
    for p in inventory:
        p['available'] = avail.get(p['productId'], 0)
    # backorders
    backorders = []
    for o in sorted_orders:
        for it in o['items']:
            short = it['qty'] - o['allocated'].get(it['productId'], 0)
            if short > 0:
                backorders.append({ 'id': f"b{backorder_counter}", 'orderId': o['orderId'], 'productId': it['productId'], 'qty': short, 'createdAt': now() })
                backorder_counter_local = 1
                # avoid incrementing global here repetitively; use simple suffix
    return { 'orders': sorted_orders, 'inventory': inventory, 'backorders': backorders }

def push_analytics_snapshot():
    try:
        a = analytics()
        analytics_history.append({ 'ts': now(), **a })
        if len(analytics_history) > 200:
            analytics_history.pop(0)
    except Exception:
        pass

def create_order(order):
    order_record = dict(order)
    order_record.update({'status': 'created', 'allocated': {}, 'picked': False, 'pickedItems': {}, 'packed': False, 'dispatched': False, 'createdAt': now()})
    orders.append(order_record)
    return order_record

def pick_order(orderId):
    o = next((x for x in orders if x['orderId'] == orderId), None)
    if not o:
        return {'error': 'order not found'}
    o['picked'] = True
    o['pickedItems'] = {it['productId']: o['allocated'].get(it['productId'], 0) for it in o['items']}
    if 'pickedAt' not in o:
        o['pickedAt'] = now()
    if o['status'] in ('allocated', 'partial'):
        o['status'] = 'picked'
    return o

def pick_item(orderId, productId, qty):
    o = next((x for x in orders if x['orderId'] == orderId), None)
    if not o:
        return {'error': 'order not found'}
    o.setdefault('pickedItems', {})
    already = o['pickedItems'].get(productId, 0)
    alloc = o['allocated'].get(productId, 0)
    to_pick = min(qty, alloc - already)
    if to_pick <= 0:
        return {'error': 'nothing to pick'}
    o['pickedItems'][productId] = already + to_pick
    all_picked = all((o['pickedItems'].get(it['productId'], 0) >= o['allocated'].get(it['productId'], 0)) for it in o['items'])
    if all_picked:
        o['picked'] = True
        if 'pickedAt' not in o:
            o['pickedAt'] = now()
        o['status'] = 'picked'
    else:
        o['status'] = 'partial-pick'
    return {'ok': True, 'order': o}

def pack_order(orderId):
    o = next((x for x in orders if x['orderId'] == orderId), None)
    if not o:
        return {'error': 'order not found'}
    if not o.get('picked'):
        return {'error': 'order not picked yet'}
    o['packed'] = True
    o['status'] = 'packed'
    if 'packedAt' not in o:
        o['packedAt'] = now()
    return o

def dispatch_order(orderId):
    o = next((x for x in orders if x['orderId'] == orderId), None)
    if not o:
        return {'error': 'order not found'}
    if not o.get('packed'):
        return {'error': 'order not packed yet'}
    o['dispatched'] = True
    o['status'] = 'dispatched'
    if 'dispatchedAt' not in o:
        o['dispatchedAt'] = now()
    o['allocated'] = {}
    try:
        push_analytics_snapshot()
    except Exception:
        pass
    return o

def damage_item(orderId, productId, qty):
    o = next((x for x in orders if x['orderId'] == orderId), None)
    inv = find_inv(productId)
    if not o or not inv:
        return {'error': 'order or product not found'}
    allocated = o['allocated'].get(productId, 0)
    damaged = min(allocated, qty)
    o['allocated'][productId] = max(0, allocated - damaged)
    o['status'] = 'exception'
    return {'order': o, 'damaged': damaged}

def get_state():
    return {'inventory': inventory, 'orders': orders, 'backorders': backorders}

def report_stats():
    counts = {}
    for o in orders:
        counts[o['status']] = counts.get(o['status'], 0) + 1
    low_stock = [p for p in inventory if p['available'] <= p['reorderThreshold']]
    bottlenecks = [o for o in orders if (now() - o['createdAt']) > 1000 * 60 * 30 and o['status'] != 'dispatched']
    return {'counts': counts, 'lowStock': low_stock, 'bottlenecks': bottlenecks, 'backorders': backorders}

def get_backorders():
    return backorders

def resolve_backorder(backorderId, qty):
    idx = next((i for i,b in enumerate(backorders) if b['id'] == backorderId), None)
    if idx is None:
        return {'error': 'backorder not found'}
    b = backorders[idx]
    inv = find_inv(b['productId'])
    if not inv:
        return {'error': 'product not found'}
    inv['available'] += qty
    b['qty'] = max(0, b['qty'] - qty)
    if b['qty'] == 0:
        backorders.pop(idx)
    return {'ok': True, 'backorder': b}

def place_reorder(productId, qty):
    inv = find_inv(productId)
    if not inv:
        return {'error': 'product not found'}
    inv['available'] += qty
    return {'ok': True, 'product': inv}

def analytics():
    dispatched = [o for o in orders if o.get('dispatched') and o.get('dispatchedAt') and o.get('createdAt')]
    avg_fulfillment = int(sum((o['dispatchedAt'] - o['createdAt']) for o in dispatched)/len(dispatched)) if dispatched else 0
    pick_list = [o for o in orders if o.get('pickedAt') and o.get('allocatedAt')]
    avg_pick = int(sum((o['pickedAt'] - o['allocatedAt']) for o in pick_list)/len(pick_list)) if pick_list else 0
    pack_list = [o for o in orders if o.get('packedAt') and o.get('pickedAt')]
    avg_pack = int(sum((o['packedAt'] - o['pickedAt']) for o in pack_list)/len(pack_list)) if pack_list else 0
    order_ages = [{'orderId': o['orderId'], 'ageMinutes': int((now() - o['createdAt'])/60000), 'status': o['status']} for o in orders]
    top_delays = sorted([o for o in order_ages if o['status'] != 'dispatched'], key=lambda x: -x['ageMinutes'])[:10]
    inventory_turnover = [{'productId': p['productId'], 'available': p['available'], 'reorderThreshold': p['reorderThreshold']} for p in inventory]
    return {'avgFulfillmentMs': avg_fulfillment, 'avgPickMs': avg_pick, 'avgPackMs': avg_pack, 'orderAges': order_ages, 'topDelays': top_delays, 'inventoryTurnover': inventory_turnover}

def get_analytics_history():
    return analytics_history

def clear_analytics_history():
    analytics_history.clear()
    return {'ok': True}

def prioritize_backorders():
    result = []
    for b in backorders:
        order = next((o for o in orders if o['orderId'] == b['orderId']), {})
        priority = order.get('priority', 0)
        age_min = int((now() - b['createdAt'])/60000)
        item = dict(b)
        item.update({'priority': priority, 'ageMin': age_min, 'orderCreatedAt': order.get('createdAt')})
        result.append(item)
    result.sort(key=lambda x: (-x['priority'], -x['ageMin']))
    return result

def simulate_notify(target, message):
    note = {'id': 'n' + str(int(now())), 'to': target, 'message': message, 'timestamp': now()}
    notifications.insert(0, note)
    if len(notifications) > 100:
        notifications.pop()
    return note

def get_notifications():
    return notifications

def clear_notifications():
    notifications.clear()
    return {'ok': True}

# Routes
@app.route('/api/inventory')
def api_inventory():
    return jsonify(get_inventory())

def api_orders():
    return jsonify(get_orders())

*** End Patch