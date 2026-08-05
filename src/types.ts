export type ToolStatus = "online" | "soon" | "offline";

export interface Tool {
  slug: string;
  name: string;
  subdomain: string;
  description: string;
  category: string;
  status: ToolStatus;
}

export interface ToolsConfig {
  root: string;
  tools: Tool[];
}
