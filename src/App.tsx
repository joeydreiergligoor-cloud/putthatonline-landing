import { useEffect, useState } from "react";
import type { ToolsConfig } from "./types";
import Hero from "./components/Hero";
import RoutingDiagram from "./components/RoutingDiagram";
import ToolGrid from "./components/ToolGrid";
import SkeletonGrid from "./components/SkeletonGrid";
import Footer from "./components/Footer";

type LoadState =
  | { status: "loading" }
  | { status: "error"; message: string }
  | { status: "ready"; config: ToolsConfig };

export default function App() {
  const [state, setState] = useState<LoadState>({ status: "loading" });

  useEffect(() => {
    let cancelled = false;

    fetch("/tools.json", { cache: "no-store" })
      .then((res) => {
        if (!res.ok) throw new Error(`tools.json niet gevonden (${res.status})`);
        return res.json();
      })
      .then((config: ToolsConfig) => {
        if (!cancelled) setState({ status: "ready", config });
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setState({
            status: "error",
            message: err instanceof Error ? err.message : "Onbekende fout bij laden van tools.json",
          });
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  if (state.status === "loading") {
    return (
      <main className="min-h-screen flex flex-col">
        <Hero root="putthatonline.com" toolCount={0} />
        <div className="flex-1">
          <SkeletonGrid />
        </div>
      </main>
    );
  }

  if (state.status === "error") {
    return (
      <main className="min-h-screen flex items-center justify-center px-6">
        <div className="text-center">
          <p className="font-mono text-sm text-soon mb-2">Kon tools.json niet laden</p>
          <p className="text-sm text-muted">{state.message}</p>
        </div>
      </main>
    );
  }

  const { root, tools } = state.config;

  return (
    <main className="min-h-screen flex flex-col">
      <div className="flex-1">
        <Hero root={root} toolCount={tools.length} />
        <RoutingDiagram tools={tools} />
        <ToolGrid tools={tools} />
      </div>
      <Footer />
    </main>
  );
}
