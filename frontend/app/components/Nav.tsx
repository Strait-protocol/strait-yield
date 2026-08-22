import Link from "next/link";

const links = [
  { href: "/", label: "Overview" },
  { href: "/deposit", label: "Deposit" },
  { href: "/borrow", label: "Borrow" },
  { href: "/positions", label: "Positions" },
];

export function Nav() {
  return (
    <nav className="flex items-center gap-6 border-b border-black/[.08] px-8 py-4 dark:border-white/[.145]">
      <span className="font-semibold tracking-tight text-black dark:text-zinc-50">
        strait-yield
      </span>
      <div className="flex gap-4 text-sm text-zinc-600 dark:text-zinc-400">
        {links.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            className="hover:text-black dark:hover:text-zinc-50"
          >
            {link.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}
