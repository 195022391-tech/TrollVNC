# Preview port (wall thumbnails)

## What changed

`src/trollvncserver.mm` adds a second LibVNCServer listener on **main port + 1** (default **5902** when VNC is **5901**).

| Port | Role |
|------|------|
| 5901 | Full control |
| 5902 | Same picture, view-only. No second scale or fps. |

Copied only while a client is connected to 5902. No client means no extra encode.

## Build without a Mac

1. Push this tree (or fork OwnGoalStudio/TrollVNC and apply the `trollvncserver.mm` changes) to **your** GitHub repo.
2. Actions → **Build TrollVNC** → Run workflow.
3. Download artifacts:
   - Jailbreak: `packages-*.deb`
   - TrollStore: `packages-bootstrap` → `.tipa`

## PC client

Wall thumbs should connect to `host:(port+1)`. Big windows keep `host:port`.
