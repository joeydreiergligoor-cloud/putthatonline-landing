import type { CSSProperties } from "react";
import type { Tool } from "../types";

const STATUS_LABEL: Record<Tool["status"], string> = {
  online: "Online",
  soon: "Binnenkort",
  offline: "Offline",
};

const STATUS_DOT: Record<Tool["status"], string> = {
  online: "bg-online",
  soon: "bg-soon",
  offline: "bg-offline",
};

export default function ToolCard({ tool, delayMs }: { tool: Tool; delayMs: number }) {
  const isLive = tool.status === "online";
  const style = { "--delay": `${delayMs}ms` } as CSSProperties;

  const content = (
    <div
      className={`group h-full rounded-card border border-border bg-panel p-5 transition-colors duration-fast ease-theme ${
        isLive ? "hover:border-accent-dim hover:bg-panel-hover" : "opacity-70"
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <h2 className="font-display text-lg font-medium text-text">{tool.name}</h2>
        <span className="flex items-center gap-1.5 shrink-0 pt-1">
          <span className={`h-2 w-2 rounded-full ${STATUS_DOT[tool.status]}`} />
          <span className="font-mono text-[11px] uppercase tracking-wide text-muted">
            {STATUS_LABEL[tool.status]}
          </span>
        </span>
      </div>

      <p className="mt-2 text-sm text-muted leading-relaxed">{tool.description}</p>

      <div className="mt-4 flex items-center justify-between gap-2">
        <span className="font-mono text-xs text-accent-dim group-hover:text-accent truncate">
          {tool.subdomain}
        </span>
        {isLive && (
          <span
            className="font-mono text-xs text-text group-hover:text-accent shrink-0"
            aria-hidden="true"
          >
            open →
          </span>
        )}
      </div>

      <span className="mt-3 inline-block font-mono text-[10px] uppercase tracking-wide text-muted">
        {tool.category}
      </span>
    </div>
  );

  const wrapperClass = "card-enter block h-full focus-visible:outline-none";

  if (!isLive) {
    return (
      <div className={wrapperClass} style={style} aria-disabled="true" title={`${tool.name} is nog niet beschikbaar`}>
        {content}
      </div>
    );
  }

  return (
    <a
      href={`https://${tool.subdomain}`}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`Open ${tool.name} op ${tool.subdomain}`}
      className={wrapperClass}
      style={style}
    >
      {content}
    </a>
  );
}
