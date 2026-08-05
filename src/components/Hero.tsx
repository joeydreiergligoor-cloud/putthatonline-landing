export default function Hero({ root, toolCount }: { root: string; toolCount: number }) {
  return (
    <header className="relative px-6 pt-16 pb-8 sm:pt-24 sm:pb-12 max-w-4xl mx-auto text-center">
      <div className="blueprint-grid absolute inset-x-0 top-0 h-64 -z-10" aria-hidden="true" />
      <p className="font-mono text-xs sm:text-sm tracking-[0.2em] uppercase text-accent mb-4">
        Eén tunnel · {toolCount} {toolCount === 1 ? "kanaal" : "kanalen"}
      </p>
      <h1 className="font-display text-3xl sm:text-5xl font-medium leading-tight text-text">
        {root}
      </h1>
      <p className="mt-5 text-base sm:text-lg text-muted max-w-xl mx-auto leading-relaxed">
        Open tools, zelf gehost. Geen account, geen tracking. Elke tool draait op
        zijn eigen subdomein — hieronder vind je de route ernaartoe.
      </p>
    </header>
  );
}
