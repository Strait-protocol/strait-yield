"use client";

import { useState } from "react";

// TODO: wire up wallet connection + contract calls once a web3 stack
// (wagmi/viem, etc.) is chosen — this is UI only for now.
export default function DepositPage() {
  const [asset, setAsset] = useState<"USDC" | "VUSD">("USDC");
  const [amount, setAmount] = useState("");

  return (
    <main className="flex flex-1 flex-col items-center px-8 py-24">
      <div className="flex w-full max-w-md flex-col gap-6">
        <div className="flex flex-col gap-1">
          <h1 className="text-2xl font-semibold tracking-tight text-black dark:text-zinc-50">
            Deposit
          </h1>
          <p className="text-sm text-zinc-600 dark:text-zinc-400">
            Supply USDC or VUSD and earn a share of borrower interest. No BTC
            exposure on this side.
          </p>
        </div>

        <div className="flex flex-col gap-4 rounded-lg border border-black/8 p-6 dark:border-white/[.145]">
          <div className="flex gap-2">
            {(["USDC", "VUSD"] as const).map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setAsset(option)}
                className={`flex-1 rounded-md border px-4 py-2 text-sm font-medium transition-colors ${
                  asset === option
                    ? "border-black bg-black text-white dark:border-white dark:bg-white dark:text-black"
                    : "border-black/8 text-zinc-600 hover:bg-black/4 dark:border-white/[.145] dark:text-zinc-400"
                }`}
              >
                {option}
              </button>
            ))}
          </div>

          <label className="flex flex-col gap-1 text-sm">
            <span className="text-zinc-600 dark:text-zinc-400">Amount</span>
            <input
              type="number"
              inputMode="decimal"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="rounded-md border border-black/8 bg-transparent px-3 py-2 text-black outline-none focus:border-black dark:border-white/[.145] dark:text-zinc-50 dark:focus:border-white"
            />
          </label>

          <button
            type="button"
            disabled
            title="Wallet connection not wired up yet"
            className="flex h-11 items-center justify-center rounded-full bg-foreground px-6 text-sm font-medium text-background opacity-50"
          >
            Connect wallet to deposit
          </button>
        </div>
      </div>
    </main>
  );
}
