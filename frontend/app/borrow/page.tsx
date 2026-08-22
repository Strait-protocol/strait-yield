"use client";

import { useMemo, useState } from "react";

const MAX_LTV_BPS = 6_000; // README §8

// TODO: wire up wallet connection + contract calls once a web3 stack
// (wagmi/viem, etc.) is chosen. BTC price is hardcoded for the LTV preview
// until the oracle (Chainlink primary, CoinGecko backup) is live.
const MOCK_BTC_USD_PRICE = 100_000;

export default function BorrowPage() {
  const [borrowAsset, setBorrowAsset] = useState<"USDC" | "VUSD">("USDC");
  const [btcCollateral, setBtcCollateral] = useState("");
  const [borrowAmount, setBorrowAmount] = useState("");

  const maxBorrow = useMemo(() => {
    const btc = parseFloat(btcCollateral);
    if (!btc || Number.isNaN(btc)) return 0;
    return (btc * MOCK_BTC_USD_PRICE * MAX_LTV_BPS) / 10_000;
  }, [btcCollateral]);

  const currentLtvBps = useMemo(() => {
    const btc = parseFloat(btcCollateral);
    const debt = parseFloat(borrowAmount);
    if (!btc || !debt || Number.isNaN(btc) || Number.isNaN(debt)) return 0;
    const collateralValue = btc * MOCK_BTC_USD_PRICE;
    return collateralValue === 0 ? 0 : Math.round((debt / collateralValue) * 10_000);
  }, [btcCollateral, borrowAmount]);

  const exceedsMaxLtv = currentLtvBps > MAX_LTV_BPS;

  return (
    <main className="flex flex-1 flex-col items-center px-8 py-24">
      <div className="flex w-full max-w-md flex-col gap-6">
        <div className="flex flex-col gap-1">
          <h1 className="text-2xl font-semibold tracking-tight text-black dark:text-zinc-50">
            Borrow
          </h1>
          <p className="text-sm text-zinc-600 dark:text-zinc-400">
            Lock BTC through the Hemi tunnel, borrow USDC or VUSD up to 60%
            LTV. Collateral only counts once Strait confirms{" "}
            <code className="rounded bg-black/6 px-1 py-0.5 font-mono text-[0.85em] dark:bg-white/8">
              popAnchored: true
            </code>
            .
          </p>
        </div>

        <div className="flex flex-col gap-4 rounded-lg border border-black/8 p-6 dark:border-white/[.145]">
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-zinc-600 dark:text-zinc-400">BTC collateral</span>
            <input
              type="number"
              inputMode="decimal"
              value={btcCollateral}
              onChange={(e) => setBtcCollateral(e.target.value)}
              placeholder="0.00"
              className="rounded-md border border-black/8 bg-transparent px-3 py-2 text-black outline-none focus:border-black dark:border-white/[.145] dark:text-zinc-50 dark:focus:border-white"
            />
          </label>

          <div className="flex gap-2">
            {(["USDC", "VUSD"] as const).map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setBorrowAsset(option)}
                className={`flex-1 rounded-md border px-4 py-2 text-sm font-medium transition-colors ${
                  borrowAsset === option
                    ? "border-black bg-black text-white dark:border-white dark:bg-white dark:text-black"
                    : "border-black/8 text-zinc-600 hover:bg-black/4 dark:border-white/[.145] dark:text-zinc-400"
                }`}
              >
                Receive {option}
              </button>
            ))}
          </div>

          <label className="flex flex-col gap-1 text-sm">
            <span className="text-zinc-600 dark:text-zinc-400">
              Borrow amount ({borrowAsset}) — max {maxBorrow.toLocaleString()}
            </span>
            <input
              type="number"
              inputMode="decimal"
              value={borrowAmount}
              onChange={(e) => setBorrowAmount(e.target.value)}
              placeholder="0.00"
              className="rounded-md border border-black/8 bg-transparent px-3 py-2 text-black outline-none focus:border-black dark:border-white/[.145] dark:text-zinc-50 dark:focus:border-white"
            />
          </label>

          <div className="flex items-center justify-between text-sm">
            <span className="text-zinc-600 dark:text-zinc-400">Resulting LTV</span>
            <span
              className={
                exceedsMaxLtv
                  ? "font-medium text-red-600 dark:text-red-400"
                  : "font-medium text-black dark:text-zinc-50"
              }
            >
              {(currentLtvBps / 100).toFixed(1)}%
            </span>
          </div>
          {exceedsMaxLtv && (
            <p className="text-xs text-red-600 dark:text-red-400">
              Exceeds the 60% max LTV — reduce the borrow amount.
            </p>
          )}

          <button
            type="button"
            disabled
            title="Wallet connection not wired up yet"
            className="flex h-11 items-center justify-center rounded-full bg-foreground px-6 text-sm font-medium text-background opacity-50"
          >
            Connect wallet to borrow
          </button>
        </div>
      </div>
    </main>
  );
}
