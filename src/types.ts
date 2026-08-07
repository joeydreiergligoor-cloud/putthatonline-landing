export type ToolStatus = "online" | "soon" | "offline";

export interface SubApp {
  name: string;
  subdomain: string;
}

export interface Tool {
  slug: string;
  name: string;
  subdomain?: string;
  description: string;
  category: string;
  status: ToolStatus;
  /** Als aanwezig, wordt deze tegel getoond als een groep met losse links naar elke app. */
  apps?: SubApp[];
}

export interface ToolsConfig {
  root: string;
  tools: Tool[];
}
