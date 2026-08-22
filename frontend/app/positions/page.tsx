// TODO: replace with real data — query the strait-yield service (which
// wraps Strait's GraphQL API + StraitYieldVault reads) once wallet
// connection is wired up. Empty state only for now.
export default function PositionsPage() {
  return (
    <main className="flex flex-1 flex-col items-center px-8 py-24">
      <div className="flex w-full max-w-2xl flex-col gap-6">
        <div className="flex flex-col gap-1">
          <h1 className="text-2xl font-semibold tracking-tight text-black dark:text-zinc-50">
            Positions
          </h1>
          <p className="text-sm text-zinc-600 dark:text-zinc-400">
            Your deposit and borrow positions, health factor, and liquidation
            risk.
          </p>
        </div>

        <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-black/8 p-12 text-center dark:border-white/[.145]">
          <p className="text-sm text-zinc-600 dark:text-zinc-400">
            Connect a wallet to see your positions.
          </p>
        </div>
      </div>
    </main>
  );
}
