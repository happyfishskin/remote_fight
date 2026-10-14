**English** | [中文（下方）](#遠端緩衝區溢位教學-demo沙箱版)

# Remote Buffer Overflow — Teaching Demo (Sandboxed)

A deliberately vulnerable socket server used to demonstrate, inside an
**isolated Docker sandbox**, how a remote buffer overflow crashes a server
(Segmentation fault / stack smashing), and how the compiler's Stack Canary
responds. Teaching only — **no exploit payload**.

## Files

| File | What it is |
|------|------------|
| `server.c` | Vulnerable server: 64-byte stack buffer, unbounded `strcpy()` |
| `server_safe.c` | Fixed server: bounded `strncpy()` |
| `client.py` | Test client: sends a normal or an oversized string |
| `Makefile` | Build with the Stack Canary on or off |
| `Dockerfile` | Fully isolated run environment |
| `rust_demo/` | Memory-safe Rust equivalents |
| `cache_timing/` | Native cache-timing side-channel demo |
| `report.pptx` / `report_en.pptx` | 14-slide deck (CN / EN), notes in each slide |
| `SCRIPT.txt` | Bilingual speaker script (also in the slide notes) |
| `PRINCIPLE.txt` | Bilingual deep-dive on the principles |

## Quick start

```bash
# 1. Build and start the sandbox (Window A — Server Console)
docker build -t overflow-demo .
docker run --rm -it -p 8888:8888 overflow-demo
```

```bash
# 2. Open a second terminal as the client (Window B — Client Console)
python3 client.py normal          # normal request -> server replies OK
python3 client.py overflow 200    # send 200 bytes -> trigger the crash
```

## The four demos (all verified on this machine)

| Command | Shows | Environment |
|---------|-------|-------------|
| `./run_demo.sh [unprotected]` | Overflow crash: exit `134` (canary) / `139` (segfault) | Docker (amd64) |
| `./run_fix_demo.sh` | `strcpy` crashes vs `strncpy` survives | Docker |
| `./run_rust_demo.sh` | Rust refuses to build / safe panic (exit 101) | Docker (rust:slim) |
| `./run_cache_demo.sh` | Cache-timing side-channel recovers a secret | **native macOS** |

### 1 · Two crashes compared
`make protected` → canary detects tampering, prints `*** stack smashing
detected ***`, aborts (exit 134). `make unprotected` → return address silently
overwritten → `Segmentation fault` (exit 139). Both crash; the difference is a
controlled abort vs. an uncontrolled fault.

### 2 · Fix at the source (`strcpy` → `strncpy`)
Same 200-byte payload: `server.c` dies (exit 139); `server_safe.c` truncates to
63 bytes, replies `OK (safe)`, and keeps running. Or start it directly:
`docker run --rm -it -p 8888:8888 -e MODE=safe overflow-demo`. Protections are
the last wall; **safe coding (bounds checks) is the real, root-cause fix**.

### 3 · Memory-safe Rust
- **Compile time**: a constant out-of-bounds index `buffer[200]` → `rustc`
  errors `index out of bounds` (`#[deny(unconditional_panic)]`), **exit 1, no
  binary**.
- **Run time**: a dynamic overflow → **safe panic, exit 101, no corruption**.

C's `strcpy` silently smashes the stack (exit 139, undefined behavior,
exploitable); Rust turns the whole class into "won't compile / safe abort".
Note: what stops the overflow is Rust's **bounds check**, not the borrow checker
(which handles lifetimes / aliasing).

### 4 · CPU cache-timing side-channel (Flush+Reload)
The core primitive behind Spectre/Meltdown. The attacker **reads no secret and
crashes nothing** — it only uses the nanosecond gap between a cache hit and a
DRAM miss.

Measured natively on Apple Silicon:
- cache hit (L1/L2): **~0.9 ns/access**
- DRAM miss: **~81 ns/access** (~90×)
- Flush+Reload: flush the cache → victim touches `secret[i]` → time each slot →
  the fastest is the secret
- Result: **the secret is recovered every run, with 0 bytes of secret memory read**

> Note: the Apple Silicon userspace timer is only ~41.67 ns/tick with no cycle
> counter, so the program batches dependent pointer-chasing loads to amplify the
> signal. This demo must run **natively** — cache behavior does not hold under
> Docker/Rosetta emulation.

> ⚠️ Teaching only: it demonstrates crashes / timing gaps, and contains no code
> that steals real data or hijacks control flow. Never expose these servers on a
> real network or public port.

---

[English（上方）](#remote-buffer-overflow--teaching-demo-sandboxed) | **中文**

# 遠端緩衝區溢位教學 Demo（沙箱版）

一個刻意設計的脆弱 Socket 伺服器，用來在**隔離的 Docker 沙箱**內展示
遠端緩衝區溢位如何造成伺服器崩潰（Segmentation fault / stack smashing），
並對比編譯器的 Stack Canary 防護機制。純教學用途，**不含任何攻擊 payload**。

## 檔案

| 檔案 | 說明 |
|------|------|
| `server.c` | 脆弱伺服器：64 bytes 堆疊緩衝區，使用無邊界檢查的 `strcpy()` |
| `client.py` | 測試客戶端：送出正常字串或超長字串 |
| `Makefile` | 可切換 Stack Canary 開 / 關 |
| `Dockerfile` | 完全隔離的執行環境 |

## 快速開始

```bash
# 1. 建立並啟動沙箱（視窗 A — Server Console）
docker build -t overflow-demo .
docker run --rm -it -p 8888:8888 overflow-demo
```

```bash
# 2. 另開一個終端機當客戶端（視窗 B — Client Console）
python3 client.py normal          # 正常連線 -> 伺服器回覆 OK
python3 client.py overflow 200    # 送 200 bytes -> 觸發崩潰
```

## 兩種崩潰的對比（錄影重點）

在容器內可用 `make` 切換編譯方式：

| 版本 | 指令 | 現象 |
|------|------|------|
| Canary ON（預設） | `make protected` | 偵測到溢位，印出 `*** stack smashing detected ***` 後**主動中止**行程 |
| Canary OFF | `make unprotected` | 回傳位址被無聲覆寫 → `Segmentation fault` |

兩者都會崩潰，差別在**「如何」**崩潰：Canary 是在函式返回前主動發現竄改並
終止，避免被竄改的回傳位址真的被使用；關閉後則是不受控的記憶體錯誤。

## 2~3 分鐘 Demo 腳本

1. **正常連線（~30 秒）**：Client 送 `Hello`，Server 印出收到的字串並回 `OK`，說明通訊正常。
2. **觸發溢位（~1 分鐘）**：Client 送 200 bytes 的 `A`，Server 終端機出現
   `stack smashing detected` 或 `Segmentation fault`，服務終止（遠端 DoS 效果）。
3. **機制說明（~1 分鐘）**：解釋 Stack Canary、ASLR、DEP/NX 等防護如何在
   未被繞過時，讓最直接的結果停在「崩潰」而非「執行惡意碼」。

## 概念回顧

- **溢位來源**：`recv()` 把封包讀進 4 KB 緩衝區，再用 `strcpy()` 複製進僅 64 bytes 的堆疊緩衝區，超出的部分覆寫相鄰堆疊內容（含回傳位址）。
- **現代防護**：ASLR（位址隨機化）、Stack Canary（金絲雀值）、DEP/NX（堆疊不可執行）共同作用，使未繞過防護時最常見的結果是行程崩潰，而非控制流被劫持。

> ⚠️ 僅在此 Docker 沙箱內執行。不要把這支伺服器暴露到真實網路或公開 Port。

## 自動播放 + 錄製(run_demo.sh + asciinema)

`run_demo.sh` 會自己依節奏跑完整個流程(正常連線 → 觸發溢位 → 顯示崩潰 →
機制說明),你不用手打指令:

```bash
./run_demo.sh                 # Canary ON  版(stack smashing detected, exit 134)
./run_demo.sh unprotected     # Canary OFF 版(Segmentation fault, exit 139)
```

### 用 asciinema 錄成可重播的終端機檔

```bash
# 錄製(跑 protected 版並存成 demo.cast)
python3 -m asciinema rec demo_protected.cast -c "./run_demo.sh protected"
python3 -m asciinema rec demo_segfault.cast  -c "./run_demo.sh unprotected"

# 重播檢查
python3 -m asciinema play demo_protected.cast
```

> 轉成 GIF 貼進報告:安裝 `agg`(asciinema gif generator)後
> `agg demo_protected.cast demo.gif`。
> 或直接用 macOS 的 `Cmd+Shift+5` 螢幕錄影,錄下 `./run_demo.sh` 的畫面即可。

## 第二個實作:從源頭修復(strcpy → strncpy)

同一份 200-byte 溢位 payload,送給兩種伺服器對照:

```bash
./run_fix_demo.sh            # 自動播放:VULNERABLE(崩潰 139) vs FIXED(安全存活)
```

- `server.c`(strcpy,無邊界檢查)→ Segmentation fault,exit 139,服務終止
- `server_safe.c`(strncpy + 補 NUL)→ payload 被截斷成 63 bytes,回 `OK (safe)`,持續運行

也可用 MODE 直接啟動安全版:

```bash
docker run --rm -it -p 8888:8888 -e MODE=safe overflow-demo
```

> 重點:防護機制(canary / ASLR / DEP)是最後一道牆;**安全的程式寫法(邊界檢查)
> 才是讓溢位無從發生的根治之道**。

## 第三個實作:現代系統防護(Rust)

同樣的溢位想法,改用記憶體安全語言 Rust —— 用官方 rust:slim 容器,無需本地安裝:

```bash
./run_rust_demo.sh
```

兩種安全機制(已驗證):
- **編譯期**:常數越界索引 `buffer[200]` → `rustc` 報 `index out of bounds`(`#[deny(unconditional_panic)]`),**exit 1,不產出 binary**。
- **執行期**:動態越界(把 200 bytes 寫進 64 的 slice)→ **安全 panic,exit 101,無記憶體破壞**。

對照:C 的 `strcpy` 是靜默破壞堆疊(exit 139,未定義行為、可被利用);Rust 把整類
漏洞變成「編不出來 / 安全中止」。這也是 Microsoft、Google、Linux kernel 正把系統
程式遷移到 Rust 的原因。

> 註:阻止溢位的是 Rust 的**邊界檢查**(bounds check),不是借用檢查器(borrow
> checker,後者管的是 lifetime / aliasing)。

## 第四個實作:CPU 快取計時側信道(Flush+Reload)

Spectre/Meltdown 的核心原語。攻擊者**不讀敏感記憶體、不讓程式崩潰**,純靠
「快取命中 vs DRAM 未命中」的奈秒級時間差,推斷出秘密值。

```bash
./run_cache_demo.sh          # 原生執行(非 Docker)—— 快取計時無法在模擬下重現
```

實測(Apple Silicon,已驗證):
- 快取命中(L1/L2):**~0.9 ns/存取**
- DRAM 未命中:**~81 ns/存取**(約 90 倍)
- Flush+Reload:清空快取 → victim 存取 `secret[i]` → 逐槽計時 → 最快者 = secret
- 結果:**每次都正確猜出秘密值,0 bytes 敏感記憶體被讀取**

> 技術註:Apple Silicon 使用者層計時器僅 ~41.67 ns/tick 且無 cycle counter,
> 因此程式用「相依指標追逐批次」放大訊號;單次存取無法直接量測。此 demo 必須
> **原生**執行,在 Docker/Rosetta 模擬下快取行為不成立。

> ⚠️ 全系列實作僅供教學:只示範「崩潰 / 時間差」,不含任何竊取真實資料或控制流
> 劫持的攻擊程式碼。
