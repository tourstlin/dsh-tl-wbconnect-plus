# PATCHES — dsh-connect-workbuddy 5.3.0 → 5.3.0-wb1

Six local patches on top of upstream **5.3.0**. Upstream is MIT,
© 2026 LaoDing (`https://github.com/dingminhua/dsh-connect-workbuddy`).

Everything was applied to the **built bundles** (`lib/index.js`,
`lib/client.js`), not to TypeScript sources — the published package ships only
build output. Each patch records the anchor it needs, so a future rebase onto a
newer upstream can be done by re-applying the same six edits.

Two source files carry all of it:

| file | size | patches |
|---|---|---|
| `lib/index.js` (host half) | 458,845 B | 1, 3 (route), 4, 5 |
| `lib/client.js` (browser half) | 531,455 B | 1, 2, 3 (UI), 4 (UI), 5 (UI), 6 |

---

## 1. Model label: drop the credit multiplier

**Where** `lib/index.js`, `function workBuddyDisplayName(info)`.

Upstream appended the catalog's `creditMultiplier` to the display name, which is
data, not a UI element, so it could not be styled away:

```js
// before
return `${info.name}${busyDisplaySuffix(info.busyLevel)} · x${info.creditMultiplier}`;
// after
return `${info.name}${busyDisplaySuffix(info.busyLevel)}`;
```

**Verify** no `workBuddyDisplayName` implementation within 240 chars appends
`creditMultiplier`.

---

## 2. `1017` badge on DeepSeek-V4.1-Flash

**Where** `lib/client.js`, `const WORKBUDDY_MODEL_LABEL_CSS`, injected by
`ensureModelLabelStyle()` (css id `dsh-connect-workbuddy/model-label.css`).

Pure CSS on an attribute selector — deliberately **not** a slot takeover:

```css
span[data-model-id^="deepseek-v4.1-flash" i]::after{
  content:"1017";
  display:inline-flex;align-items:center;flex:none;
  margin-left:4px;padding:1px 8px;border-radius:999px;
  font-size:11px;line-height:17px;font-weight:500;white-space:nowrap;
  background:…;color:…;
}
```

**Why CSS and not the slot:** `client-ui-model-selection` wraps every catalog
name in `span[data-model-id]` (chip, current-model row, option rows), so one
attribute rule reaches every placement, and the shipped
`ui-deepseek-model-label-1017` contribution keeps owning the slot — the badge
stays intact for the official `deepseek-official` / `deepseek-account`
providers.

**Verify** `content:"1017"` is present.

---

## 3. One-tap check-in for every account

**Host** `lib/index.js`: new route
`/plugins/dsh-connect-workbuddy/checkin-all`, plus
`async function checkinAllAccounts(...)`. It maps `store.accounts()` to
`{accountId, accountName}`, calls `fetchCheckinStatus` / `claimDailyCheckin`
per account with `credentialFor(id)`, and invalidates the pool's cached
check-in state through `deps.pool?.invalidateCheckin?.(region, accountId)`.
Returns `{action:"checkin", rows}`.

**Browser** `lib/client.js`: `checkinEveryAccount()` and a second header button
(`dsm-workbuddy-composer-panel-refresh dsm-workbuddy-composer-panel-checkin`)
next to the existing "test all" button, plus a one-line outcome note.

**Verify** `checkin-all` present in `index.js`; `dsm-workbuddy-composer-panel-checkin` present in `client.js`.

---

## 4. 100-credit meter for the selected account

**Host** `lib/index.js`, inserted after `function workbuddyPoolStorePath(region)`:

- `CREDIT_LEDGER_PREFIX = ".workbuddy-credit-usage"`
- `CREDIT_LEDGER_VERSION = 1`
- `CREDIT_SWITCH_THRESHOLD = 100`
- `workbuddyCreditLedgerPath(region)` → `<DSH_HOME>/.workbuddy-credit-usage.<region>.json`
- `readCreditLedger` / `writeCreditLedger` (`withFileLock` + `writeFileAtomic`)
- `foldCreditLedger(previous, accounts)` — the three rules:
  1. becoming selected resets the counter (a stint starts at zero);
  2. only the **selected** account's decreases are counted (requests bill the
     selected account);
  3. a **rise** (daily check-in, gift, purchase) moves the baseline without
     adding anything — this is why `threshold - balance` would be wrong.

`workBuddyAccountCredits` now returns `{...row, used, switchAt}`.

**Browser** `lib/client.js`: `usedById` / `switchAt` / `selectedUsed` /
`usedPercent` and the meter markup
(`dsm-workbuddy-composer-panel-meter`, `-meter-track`, `-meter-fill`,
`-meter-text`), with copy `composer.switchMeter` =
`{used} / {limit} used` / 「已用 {used} / {limit}」.

**Verify** `foldCreditLedger`, `switchAt: CREDIT_SWITCH_THRESHOLD`,
`dsm-workbuddy-composer-panel-meter`.

**Ledger file** is keyed per region and survives restarts; deleting it simply
restarts every account's count from zero.

---

## 5. Automatic handover at 100 credits

**Browser** `lib/client.js`: `autoSwitchRef` + a `useEffect` that, when
`selectedUsed >= switchAt`, calls the same `switchTo(next.id)` the row buttons
use (`writeAccountSlot` → `writeField`, read-back checked). Guarded by
`switchingId` / `busy` / `checkingIn` and a re-entrancy ref so it fires once per
crossing.

Also added: a slow background refresh while the panel is **closed**
(`COMPOSER_ACCOUNT_REFRESH_INTERVAL_MS * 3`, i.e. three minutes), because the
per-account balances previously refreshed only while the panel was open — a
user who never opened it would never reach the threshold.

**Verify** `autoSwitchRef` present; the effect references `switchTo`.

---

## 6. Check-in button in the global region

**Browser** `lib/client.js`: the button was gated
`disabled: … || activeRegion !== "cn"` with
`style:{display: activeRegion === "cn" ? undefined : "none"}`. Both removed.

Added copy `composer.checkinInactive`:

- en: `No check-in campaign is running in this region right now`
- zh: 「本区当前没有签到活动（国际版暂未开放）」

and a softener that maps the gateway's `not active` / 「未开启」/「已过期」
answer to that sentence instead of surfacing the raw English string.

**Measured upstream state (2026-10-24)** — the international gateway **does**
expose the endpoint, it simply has no active campaign:

```
POST https://www.workbuddy.ai/v2/billing/meter/checkin-activity-status
 -> {"code":0,"data":{"active":false,"start_time":"","end_time":"",
                      "theme_name":"","season":0,"claim_button_text":""}}

POST https://www.workbuddy.ai/v2/billing/meter/daily-checkin
 -> {"code":10001,"msg":"check-in activity is not active"}
```

For comparison, the CN gateway on the same day:

```
-> {"code":0,"data":{"active":true,"season":10,"theme_name":"Buddy加油站",
                      "end_time":"2026-12-31 23:59:59","daily_credit":100}}
```

So patch 6 changes the button from *hidden* to *present and honest*. It cannot
grant credits that the region does not offer.

**Verify** `composer.checkinInactive` present and `activeRegion !== "cn"` absent.

---

## Re-applying these patches after an upstream release

The patches were applied by small Python scripts that assert a **unique anchor**
before writing, so a changed upstream file fails loudly instead of being
silently corrupted. The anchors, in order:

1. `function workBuddyDisplayName(` — the template literal with `creditMultiplier`
2. `const WORKBUDDY_MODEL_LABEL_CSS` — the CSS template literal
3. `const WORKBUDDY_CHECKIN_ALL_PATH` / the panel header JSX `<div className:"dsm-workbuddy-composer-panel-head">`
4. `function workbuddyPoolStorePath(` (insertion point for the ledger block) and `async function workBuddyAccountCredits(`
5. `const usedById = new Map(` (meter state) and the `fetchAccountCredits` polling effect
6. `disabled: checkingIn || testing || activeRegion !== "cn"` and the
   `composer.checkinNone` locale entries

Re-run them in that order against the new bundle, then run `verify.ps1`.

---

## Licence

MIT, © 2026 LaoDing. This build is a modified redistribution; the original
`LICENSE` and `THIRD_PARTY_NOTICES.md` are included unmodified in
`payload/dsh-connect-workbuddy/`. The six patches above are offered under the
same MIT terms.
