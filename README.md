# OmniStock Central — Enterprise Warehouse Controller

A state-of-the-art intelligent warehouse inventory allocation, picking, packing, dispatching, exception handling, and visual analytics platform.


Run backend:

```bash
cd backend
npm install
npm start
```

Then open `frontend/index.html` in your browser and click "Run Allocation" to see allocation results.

Notes:
- Backend runs on port 4000.
- The allocation logic is in `backend/data.js` and demonstrates priority-based allocation with reallocation from lower-priority orders when needed.

New demo endpoints:

- `POST /api/allocate` : run allocation
- `GET /api/state` : current state (inventory + orders)
- `POST /api/pick/:orderId` : mark order picked
- `POST /api/pack/:orderId` : mark order packed
- `POST /api/dispatch/:orderId` : finalize and dispatch order
- `POST /api/damage` : report damaged item `{orderId, productId, qty}`
 - `POST /api/damage` : report damaged item `{orderId, productId, qty, autoResolve}`. If `autoResolve` is true the server will re-run allocation to attempt reassignments and return reorder suggestions.
- `GET /api/report` : basic analytics (low stock, bottlenecks)
 - `GET /api/backorders` : list generated backorders
 - `POST /api/resolve-backorder` : resolve a backorder `{backorderId, qty}` (receives stock)
 - `POST /api/reorder` : place a simulated reorder `{productId, qty}`
 - `GET /api/analytics` : operational analytics and bottleneck summary
 - `GET /api/backorder-priority` : prioritized backorder list (by order priority and age)
 - `POST /api/notify` : simulate sending a notification `{target, message}`
 - `GET /api/notifications` : list recent notifications
 - `POST /api/notifications/clear` : clear notification log

One-click helpers (Windows):

PowerShell script to install and start backend and open UI:

```powershell
.\run-backend.ps1
```

Or run both steps via:

```powershell
.\run-all.ps1
```

Or use the batch file:

```cmd
start-backend.bat
```

Demo script
-----------

Run `demo.ps1` after starting the backend to exercise an end-to-end scenario (allocation, picking, packing, dispatch, damage, backorder resolution):

```powershell
cd "c:\Users\ADMIN\Desktop\samrt warehouse"
.\demo.ps1
```

Python backend (no Node/npm)
--------------------------------

If you don't have Node installed, you can run the Python backend instead. From the workspace root:

```powershell
cd "c:\Users\ADMIN\Desktop\samrt warehouse\python_backend"
.\run-python.ps1
```

This starts a Flask server on port 4000 compatible with the frontend.

Docker
------

Build and run with Docker (serves API + frontend):

```bash
docker build -t smart-warehouse:latest .
docker run -p 4000:4000 smart-warehouse:latest
```

Or with docker-compose:

```bash
docker-compose up --build
```

Open http://localhost:4000 in your browser.

Final Deliverable
-----------------

The project is complete and ready for handoff. To create a packaged zip containing the app, run from the workspace root in PowerShell:

```powershell
.\package.ps1
# produces smart-warehouse.zip
```

Contents included: `frontend`, `backend`, `python_backend`, docs, demo scripts, Dockerfile and compose file, and helper scripts.

If you need a GitHub release or a tarball for Linux, tell me and I will add that packaging step.
