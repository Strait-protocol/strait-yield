# strait-yield — Technical Spec

**Status:** Draft v0.1
**Parent project:** Strait (Bitcoin-final, reorg-proof tunnel indexer on Hemi mainnet)
**One-liner:** Stake BTC as collateral, borrow USDC on Ethereum, spend it anywhere — backed by Strait's proven `popAnchored: true` correctness layer instead of a custodian.

---

## 1. Why this exists

Strait already solved the hard problem underneath any BTC-collateralized product: proving, without trusting a custodian, that a specific BTC UTXO is real, locked, and finalized (`popAnchored: true`, reorg-proof via `strait-bitcoin`). `strait-yield` is the lending/liquidation layer built on top of that primitive. It is not a new correctness problem — it's a new *product* on infrastructure you've already shipped and had reviewed live by the Hemi team.

## 2. Product summary

**Model: peer-to-pool, dual-asset, two-sided market.**

| Parameter | Value |
|---|---|
| Collateral asset (borrow side) | BTC (locked via Hemi Bitcoin Tunnel) |
| Pool assets (deposit + borrow side) | USDC and VUSD — both supported |
| Max LTV | 60% |
| Liquidation threshold | 80% |
| Liquidation mechanism | Dutch auction via `StraitLiquidator` |
| Collateral custody | Non-custodial — BTC locked in Hemi tunnel contracts, tracked via Strait indexing |
| Depositor reward | Percentage share of the pool, funded by borrower interest |
| Spend mechanism | TBD — see §7 |

**Two sides of the market:**
- **Depositors** — stake USDC and/or VUSD into the pool, earn a proportional share of borrower interest as yield. No BTC exposure required on this side.
- **Borrowers** — stake BTC as collateral, borrow USDC or VUSD out of the pool up to 60% LTV, pay interest that flows back to depositors.

This is the standard peer-to-pool lending shape (Aave/Compound-style), with BTC as the only collateral type in v1 and dual borrow/deposit assets (USDC, VUSD) rather than a single stablecoin.

## 3. User flows

**Depositor (lender) flow:**
1. **Deposit** — User supplies USDC and/or VUSD into the `StraitYieldVault` pool.
2. **Accrue** — Pool share accrues a proportional cut of interest paid by borrowers, tracked as a yield-bearing position (share-token model, similar to Aave's aTokens/Compound's cTokens).
3. **Withdraw** — User redeems their pool share for underlying USDC/VUSD plus accrued yield, subject to available pool liquidity.

**Borrower flow:**
1. **Deposit collateral** — User sends BTC through the existing Hemi Bitcoin Tunnel (already indexed by `strait-bitcoin`). Collateral is only recognized once `popAnchored: true` is confirmed by the indexer — no assumption of finality before Bitcoin-side proof exists.
2. **Borrow** — User requests a loan (USDC or VUSD, borrower's choice) against locked BTC, up to 60% LTV, drawn from the shared pool.
3. **Monitor** — Position health (current LTV vs. BTC price) tracked continuously. BTC price feed needed (see §6).
4. **Liquidation (if triggered)** — If LTV crosses 80%, `StraitLiquidator` initiates a Dutch auction on the BTC collateral to repay the loan and protect depositors.
5. **Repay & withdraw** — User repays USDC/VUSD + interest. BTC collateral is released back through the tunnel only once the debt is repaid in full (no partial-unlock in v1). Interest paid flows into the pool for depositors.

## 4. Architecture

**Consumes Strait as a service, not as shared Rust crates.** `strait-yield` is a separate deployable that talks to the existing Strait indexer over its already-proven external surfaces, rather than importing `strait-core`/`strait-bitcoin`/`strait-join` as library dependencies:

```
Existing Strait indexer (unchanged, running independently)
  strait-bitcoin/strait-join → does the BTC-side correctness work internally
  strait-api                 → GraphQL surface [already proven with strait-analytics]
  webhook                    → event push [already tested end-to-end]

strait-yield service (NEW, standalone)
  ├─ webhook listener   → subscribes to Strait's collateral-lock / popAnchored events
  ├─ GraphQL client     → queries Strait for on-demand collateral verification, position lookups
  ├─ loan lifecycle      → state machine, LTV calc, health monitoring (new logic, no reuse needed here)
  └─ liquidator          → Dutch auction engine, triggers off loan health checks

strait-yield-contracts   → NEW: Solidity — loan issuance, collateral lock/release, liquidation hooks
```

**Why this over direct crate reuse:**
- **Decoupled deployment** — `strait-yield` can ship, version, and scale independently of the core indexer; no shared build/release coordination.
- **Proves the API's value** — this becomes the first real downstream consumer of Strait's public webhook + GraphQL surface, which directly supports the earlier idea of productizing that surface for other builders.
- **No duplicated correctness logic** — the hard BTC-side work (`popAnchored`, reorg-proofing, UUID join) stays exactly once, inside Strait itself; `strait-yield` only consumes verified events/queries, never re-derives them.
- **Language-agnostic** — `strait-yield` doesn't have to be Rust or share a workspace; it just needs an HTTP/webhook client, which loosens future implementation choices.

Practically: on collateral deposit, `strait-yield` either (a) receives a webhook push once Strait confirms `popAnchored: true` for the relevant tunnel transaction, or (b) polls Strait's GraphQL API for the collateral position's status if a push is missed/delayed. The webhook is the primary path since it's already tested end-to-end; GraphQL serves as the fallback/reconciliation path and for on-demand lookups (e.g. displaying position status in a UI).

## 5. Smart contract surface (Ethereum + Hemi)

- **Hemi side:** BTC collateral lock reuses the existing `BitcoinTunnelManager` flow — no new BTC-side contract needed, just a new event type (`CollateralLocked`) consumed by `strait-yield`.
- **Hemi/Ethereum side (new):**
  - `StraitYieldVault` — dual-asset pool contract. Accepts USDC/VUSD deposits (mints share tokens), accepts BTC-collateralized loan requests, tracks outstanding debt + accrued interest per borrower and per depositor share
  - `StraitLiquidator` — Dutch auction contract; starts price high, decays over time, first bidder to accept wins the BTC collateral in exchange for covering the debt
  - Oracle consumer — needs a BTC/USD price feed (see open question in §6)

## 6. Open questions / decisions needed

*Decisions below are current best answers, not final — subject to change as the project develops.*

- **Deployment chain for the pool:** ✅ **Decided (subject to change):** `StraitYieldVault` deploys Hemi-native. Hemi's seamless BTC↔ETH interaction is the deciding factor — it's the natural home for VUSD, BTC collateral is already Hemi-tunneled, and it avoids bridging USDC in from Ethereum for the loan leg.
- **Price oracle:** ✅ **Decided (subject to change):** Chainlink BTC/USD is primary. CoinGecko (via `strait-analytics`'s existing integration) serves as the backup/fallback feed if Chainlink is unavailable or stale — still need to define the staleness threshold that triggers failover.
- **Interest rate model:** ✅ **Decided (subject to change):** Utilization-based (Aave/Compound-style), priced at industry-standard rate + 1%. Exact utilization curve/kink parameters still TBD, to be tuned with backtesting.
- **Cross-asset pool accounting:** ✅ **Decided (subject to change):** USDC and VUSD are distinct assets and are never bridged/converted between each other within the vault — they run as two separate pools with independent accounting. The borrower chooses which asset (USDC or VUSD) they receive the loan in at borrow time; that choice is independent of which asset(s) they deposit as a lender.
- **Liquidation bot / keeper network:** ✅ **Decided (subject to change):** Self-run bot for v1 — monitors position health and triggers `StraitLiquidator` directly. A permissionless keeper-incentive model (gas rebate + bounty) can be layered on later once there's real TVL and decentralizing this liveness dependency matters more.
- **Depositor yield source:** ✅ **Decided (subject to change):** Yield is purely borrower interest — no protocol emissions/incentive token for v1. A token/points system is out of scope unless revisited later.
- **Bad debt handling:** ✅ **Decided (subject to change):** If a liquidation auction fails to fully cover outstanding debt (e.g. BTC price gaps down faster than the auction can clear), the protocol claims/absorbs the resulting bad debt rather than socializing the loss across depositor balances. Funding source for this (protocol treasury, insurance fund, etc.) still TBD.

## 7. "Spend anywhere" — scope decision needed

This phrase covers two very different builds. Pick one for v1:

- **Option A — Liquid USDC only:** Loan proceeds land as standard USDC in the user's Ethereum wallet. "Spend anywhere" just means USDC's native liquidity/composability — swappable, bridgeable, off-rampable through any existing venue. **No new infra required beyond the vault itself.**
- **Option B — Card/off-ramp integration:** Direct crypto debit card (e.g. via Bridge, Rain, or similar card-issuing partner) wired to the USDC balance for real-world spend. Pulls in a compliance/KYC surface and a third-party integration — significantly larger scope, likely a v2 feature rather than v1.

**Recommendation:** Ship Option A first. It's a complete, usable product on its own and doesn't block on a card-issuer partnership. Option B can be layered on once the lending core is proven.

## 8. Risk parameters (initial, subject to backtesting)

*Values below are current working assumptions, not final — subject to change as the project develops.*

| Parameter | Value | Notes |
|---|---|---|
| Max LTV | 60% | Origination cap |
| Liquidation threshold | 80% | Triggers Dutch auction |
| Liquidation penalty | 0.5% | Set to industry-standard rate rather than the earlier 5–15% placeholder — revisit after backtesting |
| Auction start price | TBD | Typically starts above spot, decays to spot or below over auction window |
| Auction duration | 24h | Needs backtesting against BTC volatility to avoid under/over-selling collateral |
| Bad debt (uncovered by auction) | Protocol-absorbed | See §6 — protocol claims shortfall rather than socializing it across depositors |

## 9. Build phases

**Phase 1 — Core loan lifecycle**
- `strait-yield` crate: loan state machine, LTV calculation, position tracking
- `StraitYieldVault` contract: deposit, borrow, repay, withdraw (no liquidation yet)
- Wire to existing `strait-bitcoin`/`strait-join` for collateral verification

**Phase 2 — Liquidation engine**
- `strait-liquidator` crate + `StraitLiquidator` contract
- Price oracle integration
- Keeper/bot for triggering liquidations

**Phase 3 — Analytics & UX**
- Extend `strait-analytics` GraphQL schema to cover loan positions, health factors, liquidation history
- Frontend: position dashboard, borrow/repay flow, liquidation risk warnings

**Phase 4 — Spend layer (if pursuing Option B)**
- Card issuer integration
- KYC/compliance flow

## 10. Dependencies on decisions outside this doc

- Grant outcome may affect timeline/resourcing but shouldn't block starting Phase 1, since this reuses already-shipped indexing infra.
- ✅ Resolved: `strait-yield` launches on Hemi-native liquidity (see §6) — contract deployment targets in §5 should assume Hemi as the primary chain.

---

*Next step: resolve the open questions in §6–7, then break Phase 1 into concrete GitHub issues against the new crates.*
