#!/usr/bin/env python3
"""Patch OpenWhale to serve AInux login page at root / and redirect unauthenticated users."""
import pathlib

# 1. Patch index.ts - add root / route for AInux login page
f = pathlib.Path('/opt/ainux/openwhale/src/index.ts')
code = f.read_text()
inject = '''
    // AInux login page at root
    app.get("/", async (c) => {
        const { readFileSync } = await import("node:fs");
        const { join, dirname } = await import("node:path");
        const { fileURLToPath } = await import("node:url");
        const __dir = dirname(fileURLToPath(import.meta.url));
        const html = readFileSync(join(__dir, "dashboard/ainux-login.html"), "utf-8");
        return c.html(html);
    });
'''
marker = 'app.route("/dashboard"'
if marker in code:
    idx = code.index(marker)
    line_end = code.index(';', idx) + 1
    code = code[:line_end] + chr(10) + inject + code[line_end:]
    f.write_text(code)
    print('OK: Patched index.ts with AInux login route')
else:
    print('WARNING: Could not find marker in index.ts')

# 2. Patch main.js - redirect unauthenticated to / (AInux login)
m = pathlib.Path('/opt/ainux/openwhale/src/dashboard/main.js')
js = m.read_text()
old_render = 'const isAuth = await checkAuth();'
new_render = """const isAuth = await checkAuth();
    // AInux: redirect to OS login if not authenticated
    if (!isAuth && !localStorage.getItem('owSessionId')) {
      window.location.href = '/';
      return;
    }"""
if old_render in js:
    js = js.replace(old_render, new_render)
    m.write_text(js)
    print('OK: Patched main.js with AInux auth redirect')
else:
    print('WARNING: Could not find auth marker in main.js')
