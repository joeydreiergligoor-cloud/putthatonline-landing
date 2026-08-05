import { useEffect, useState } from "react";
import type { Tool } from "../types";

const STATUS_STROKE: Record<Tool["status"], string> = {
  online: "stroke-online",
  soon: "stroke-soon",
  offline: "stroke-offline",
};

const MAX_VISIBLE = 7;

interface Segment {
  length: number;
  delay: number;
  duration: number;
}

/**
 * Decoratief PCB-achtig schema. Bestaat uit drie soorten lijnstukken die elk
 * maar ÉÉN keer getekend worden (geen overlappende paden):
 *   1) de stam van root naar het knooppunt (verticaal)
 *   2) de "bus" op dat knooppunt (horizontaal, één keer, niet per tak)
 *   3) per tool één eigen verticaal stukje naar zijn eindpunt
 * De lijnen "tekenen" zichzelf via een CSS-transition op stroke-dashoffset
 * (bewust geen @keyframes — dat bleek onbetrouwbaar te renderen voor SVG
 * stroke-dasharray i.c.m. CSS custom properties). Puur decoratief
 * (aria-hidden) — de echte informatie staat in de kaarten eronder.
 */
export default function RoutingDiagram({ tools }: { tools: Tool[] }) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const raf = requestAnimationFrame(() => setMounted(true));
    return () => cancelAnimationFrame(raf);
  }, []);

  const overflow = Math.max(0, tools.length - MAX_VISIBLE);
  const shown = overflow > 0 ? tools.slice(0, MAX_VISIBLE) : tools;

  const width = 1000;
  const rootY = 18;
  const midY = 70;
  const endY = 122;
  const marginX = 70;
  const slotCount = shown.length + (overflow > 0 ? 1 : 0);
  const step = slotCount > 1 ? (width - marginX * 2) / (slotCount - 1) : 0;
  const rootX = width / 2;
  const xFor = (i: number) => (slotCount === 1 ? rootX : marginX + step * i);

  const xs = Array.from({ length: slotCount }, (_, i) => xFor(i));
  const minX = Math.min(rootX, ...xs);
  const maxX = Math.max(rootX, ...xs);

  const TRUNK_DUR = 350;
  const BUS_DUR = 250;
  const DROP_DUR = 220;
  const STAGGER = 70;

  const trunkDelay = 0;
  const busDelay = trunkDelay + TRUNK_DUR;
  const dropStart = busDelay + (slotCount > 1 ? BUS_DUR : 0);

  const lineProps = ({ length, delay, duration }: Segment) => ({
    strokeDasharray: length,
    strokeDashoffset: mounted ? 0 : length,
    transition: `stroke-dashoffset ${duration}ms var(--motion-ease) ${delay}ms`,
  });

  const nodeProps = (delay: number) => ({
    opacity: mounted ? 1 : 0,
    transform: mounted ? "scale(1)" : "scale(0.5)",
    transformOrigin: "center" as const,
    transition: `opacity 150ms var(--motion-ease) ${delay}ms, transform 150ms var(--motion-ease) ${delay}ms`,
  });

  return (
    <div className="max-w-5xl mx-auto px-6 -mt-2 mb-4 hidden sm:block" aria-hidden="true">
      <svg viewBox={`0 0 ${width} 150`} className="w-full h-auto" preserveAspectRatio="xMidYMid meet">
        {/* Stam: root -> knooppunt */}
        <path
          d={`M ${rootX} ${rootY} L ${rootX} ${midY}`}
          fill="none"
          className="stroke-border"
          strokeWidth="1.5"
          style={lineProps({ length: midY - rootY, delay: trunkDelay, duration: TRUNK_DUR })}
        />

        {/* Bus: het knooppunt zelf, één horizontale lijn (niet per tak) */}
        {slotCount > 1 && (
          <path
            d={`M ${minX} ${midY} L ${maxX} ${midY}`}
            fill="none"
            className="stroke-border"
            strokeWidth="1.5"
            style={lineProps({ length: maxX - minX, delay: busDelay, duration: BUS_DUR })}
          />
        )}

        <circle cx={rootX} cy={rootY} r="5" className="fill-bg stroke-accent" strokeWidth="2" />

        {shown.map((tool, i) => {
          const x = xFor(i);
          const dashed = tool.status !== "online";
          const dropDelay = dropStart + i * STAGGER;
          return (
            <g key={tool.slug}>
              <path
                d={`M ${x} ${midY} L ${x} ${endY}`}
                fill="none"
                className={`stroke-border ${dashed ? "trace-dashed" : ""}`}
                strokeWidth="1.5"
                style={lineProps({ length: endY - midY, delay: dropDelay, duration: DROP_DUR })}
              />
              <circle
                cx={x}
                cy={endY}
                r="4"
                className={`fill-bg ${STATUS_STROKE[tool.status]}`}
                strokeWidth="2"
                style={nodeProps(dropDelay + DROP_DUR)}
              />
            </g>
          );
        })}

        {overflow > 0 &&
          (() => {
            const x = xFor(shown.length);
            const dropDelay = dropStart + shown.length * STAGGER;
            return (
              <g>
                <path
                  d={`M ${x} ${midY} L ${x} ${endY}`}
                  fill="none"
                  className="stroke-border trace-dashed"
                  strokeWidth="1.5"
                  style={lineProps({ length: endY - midY, delay: dropDelay, duration: DROP_DUR })}
                />
                <circle
                  cx={x}
                  cy={endY}
                  r="9"
                  className="fill-bg stroke-muted"
                  strokeWidth="1.5"
                  style={nodeProps(dropDelay + DROP_DUR)}
                />
                <text
                  x={x}
                  y={endY + 4}
                  textAnchor="middle"
                  className="fill-muted"
                  style={{ ...nodeProps(dropDelay + DROP_DUR), font: "600 9px var(--font-mono)" }}
                >
                  +{overflow}
                </text>
              </g>
            );
          })()}
      </svg>
    </div>
  );
}

