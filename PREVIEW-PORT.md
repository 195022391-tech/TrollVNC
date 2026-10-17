# Preview port (wall thumbnails)

## What changed

`src/trollvncserver.mm` adds a second LibVNCServer listener on **main port + 1** (default **5902** when VNC is **5901**).

| Port | Role | Size | FPS |
|------|------|------|-----|
| 5901 | Full control (unchanged) | phone scale setting | phone fps setting |
| 5902 | View-only wall preview | **Small Window Scale** (default 0.4) | **Small Window Frame Rate** (default 20) |

One capture; each publish also downscales into the preview framebuffer.

## Build without a Mac

1. Push this tree (or fork OwnGoalStudio/TrollVNC and apply the `trollvncserver.mm` changes) to **your** GitHub repo.
2. Actions → **Build TrollVNC** → Run workflow.
3. Download artifacts:
   - Jailbreak: `packages-*.deb`
   - TrollStore: `packages-bootstrap` → `.tipa`

## PC client

Wall thumbs should connect to `host:(port+1)`. Big windows keep `host:port`.
