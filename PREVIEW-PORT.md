# Preview port (wall thumbnails)

## What changed

`src/trollvncserver.mm` adds a second LibVNCServer listener on **main port + 1** (default **5902** when VNC is **5901**).

| Port | Role |
|------|------|
| 5901 | Big window: Output Scale + Frame Rate (or PC 大窗 settings) |
| 5902 | Small window: PreviewScale + PreviewFps (or PC 小窗 settings), view-only |

Preview only encodes while someone is on 5902. Publish runs outside the main client lock.

## Build without a Mac

1. Push this tree (or fork OwnGoalStudio/TrollVNC and apply the `trollvncserver.mm` changes) to **your** GitHub repo.
2. Actions → **Build TrollVNC** → Run workflow.
3. Download artifacts:
   - Jailbreak: `packages-*.deb`
   - TrollStore: `packages-bootstrap` → `.tipa`

## PC client

Wall thumbs should connect to `host:(port+1)`. Big windows keep `host:port`.
