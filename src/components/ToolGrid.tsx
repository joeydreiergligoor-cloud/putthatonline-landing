import { useMemo, useState } from "react";
import type { Tool } from "../types";
import ToolCard from "./ToolCard";

export default function ToolGrid({ tools }: { tools: Tool[] }) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<string | null>(null);

  const categories = useMemo(
    () => Array.from(new Set(tools.map((t) => t.category))).sort((a, b) => a.localeCompare(b)),
    [tools]
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return tools.filter((t) => {
      const matchesQuery =
        q === "" || t.name.toLowerCase().includes(q) || t.description.toLowerCase().includes(q);
      const matchesCategory = category === null || t.category === category;
      return matchesQuery && matchesCategory;
    });
  }, [tools, query, category]);

  if (tools.length === 0) {
    return (
      <p className="text-center text-muted font-mono text-sm py-16">
        Nog geen tools geconfigureerd in tools.json.
      </p>
    );
  }

  // Filterbalk pas tonen zodra hij nut heeft — bij een handjevol tools is hij ruis.
  const showFilters = tools.length > 5 || categories.length > 1;

  return (
    <div className="max-w-5xl mx-auto px-6 pb-20">
      {showFilters && (
        <div className="mb-6 flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between">
          <label className="relative flex-1 sm:max-w-xs">
            <span className="sr-only">Zoek een tool</span>
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Zoek een tool…"
              className="w-full rounded-card border border-border bg-panel px-3 py-2 text-sm text-text placeholder:text-muted focus:outline-none focus-visible:outline-2 focus-visible:outline-accent"
            />
          </label>

          {categories.length > 1 && (
            <div className="flex flex-wrap gap-2" role="group" aria-label="Filter op categorie">
              <button
                type="button"
                onClick={() => setCategory(null)}
                className={`rounded-pill border px-3 py-1 text-xs font-mono transition-colors duration-fast ${
                  category === null
                    ? "border-accent text-accent"
                    : "border-border text-muted hover:text-text"
                }`}
                aria-pressed={category === null}
              >
                Alles
              </button>
              {categories.map((cat) => (
                <button
                  key={cat}
                  type="button"
                  onClick={() => setCategory(cat)}
                  className={`rounded-pill border px-3 py-1 text-xs font-mono transition-colors duration-fast ${
                    category === cat
                      ? "border-accent text-accent"
                      : "border-border text-muted hover:text-text"
                  }`}
                  aria-pressed={category === cat}
                >
                  {cat}
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {filtered.length === 0 ? (
        <p className="text-center text-muted font-mono text-sm py-16">
          Geen tools gevonden{query ? ` voor "${query}"` : ""}.
        </p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((tool, i) => (
            <ToolCard key={tool.slug} tool={tool} delayMs={i * 60} />
          ))}
        </div>
      )}
    </div>
  );
}
