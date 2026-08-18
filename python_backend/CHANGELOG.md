# Changelog - python_backend

## [Unreleased] - 2026-08-18

- Fix: set explicit `instance_path` and absolute `static_folder` in `app.py` to avoid
  a `pkgutil.get_loader` incompatibility on Python 3.14 that prevented the Flask app
  from starting. This ensures the frontend is served and `app.run()` binds to port 4000.

