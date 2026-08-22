import Link from "next/link";

const stats = [
  { label: "Max LTV", value: "60%" },
  { label: "Liquidation threshold", value: "80%" },
  { label: "Liquidation penalty", value: "0.5%" },
  { label: "Auction duration", value: "24h" },
];

export default function Home() {
  return (
    <main className="flex flex-1 flex-col items-center px-8 py-24">
      <div className="flex w-full max-w-2xl flex-col gap-10">
        <div className="flex flex-col gap-4">
          <h1 className="text-3xl font-semibold tracking-tight text-black dark:text-zinc-50">
            Stake BTC. Borrow USDC or VUSD.
          </h1>
          <p className="text-lg leading-8 text-zinc-600 dark:text-zinc-400">
            Non-custodial BTC-collateralized lending, backed by Strait&apos;s
            proven <code className="rounded bg-black/6 px-1.5 py-0.5 font-mono text-[0.9em] dark:bg-white/8">popAnchored</code> correctness
            layer instead of a custodian.
          </p>
        </div>

        <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
          {stats.map((stat) => (
            <div
              key={stat.label}
              className="flex flex-col gap-1 rounded-lg border border-black/8 p-4 dark:border-white/[.145]"
            >
              <span className="text-xl font-semibold text-black dark:text-zinc-50">
                {stat.value}
              </span>
              <span className="text-xs text-zinc-600 dark:text-zinc-400">
                {stat.label}
              </span>
            </div>
          ))}
        </div>

        <div className="flex gap-4">
          <Link
            href="/deposit"
            className="flex h-11 items-center justify-center rounded-full bg-foreground px-6 text-sm font-medium text-background transition-colors hover:bg-[#383838] dark:hover:bg-[#ccc]"
          >
            Deposit &amp; earn
          </Link>
          <Link
            href="/borrow"
            className="flex h-11 items-center justify-center rounded-full border border-black/8 px-6 text-sm font-medium transition-colors hover:bg-black/4 dark:border-white/[.145] dark:hover:bg-[#1a1a1a]"
          >
            Borrow against BTC
          </Link>
        </div>
      </div>
    </main>
  );
}
