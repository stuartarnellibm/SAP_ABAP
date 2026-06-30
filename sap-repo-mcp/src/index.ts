#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import axios, { AxiosInstance } from 'axios';

// Environment variables for watsonx Orchestrate REST API
const WXO_API_URL = process.env.WXO_API_URL;
const WXO_API_KEY = process.env.WXO_API_KEY;
const WXO_AGENT_ID = process.env.WXO_AGENT_ID || 'SA_SAP_Repo_99901A';

if (!WXO_API_URL) {
  throw new Error('WXO_API_URL environment variable is required');
}

if (!WXO_API_KEY) {
  throw new Error('WXO_API_KEY environment variable is required');
}

// Parse the API key to extract username and password
// Format: base64(k1:username:password:extra)
function parseApiKey(apiKey: string): { username: string; password: string } {
  try {
    const decoded = Buffer.from(apiKey, 'base64').toString('utf-8');
    const parts = decoded.split(':');
    if (parts.length >= 3) {
      return {
        username: parts[1],
        password: parts[2]
      };
    }
  } catch (error) {
    console.error("Failed to parse API key:", error);
  }
  throw new Error("Invalid API key format. Expected base64-encoded 'k1:username:password:extra'");
}

const credentials = parseApiKey(WXO_API_KEY);

// Types for watsonx Orchestrate API
interface ChatMessage {
  role: 'user' | 'assistant';
  content: string | Array<{
    response_type: string;
    text?: string;
    [key: string]: any;
  }>;
}

interface TokenResponse {
  access_token: string;
  token_type: string;
}

// Global token cache
let cachedToken: string | null = null;
let tokenExpiry: number = 0;

// Function to get or refresh access token
async function getAccessToken(): Promise<string> {
  // Return cached token if still valid (with 5 minute buffer)
  if (cachedToken && Date.now() < tokenExpiry - 300000) {
    return cachedToken;
  }

  try {
    const params = new URLSearchParams();
    params.append('username', credentials.username);
    params.append('password', credentials.password);
    params.append('grant_type', 'password');

    const response = await axios.post<TokenResponse>(
      `${WXO_API_URL}/v1/auth/token`,
      params,
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    cachedToken = response.data.access_token;
    // Set expiry to 1 hour from now (tokens typically last 1 hour)
    tokenExpiry = Date.now() + 3600000;
    
    return cachedToken;
  } catch (error: any) {
    console.error('Failed to get access token:', error.response?.data || error.message);
    throw new Error(`Authentication failed: ${error.response?.data?.detail || error.message}`);
  }
}

// Create axios instance for watsonx Orchestrate API
const wxoApi: AxiosInstance = axios.create({
  baseURL: WXO_API_URL,
  timeout: 120000, // 2 minutes for complex queries
});

// Add request interceptor to inject fresh token
wxoApi.interceptors.request.use(async (config) => {
  const token = await getAccessToken();
  config.headers.Authorization = `Bearer ${token}`;
  config.headers['Content-Type'] = 'application/json';
  return config;
});

// Create an MCP server
const server = new McpServer({
  name: "sap-repo-mcp",
  version: "0.1.0"
});

/**
 * Helper function to chat with an agent
 */
async function chatWithAgent(
  agentId: string,
  message: string,
  threadId?: string,
  includeReasoning: boolean = false
): Promise<{ response: string; thread_id: string; reasoning?: any }> {
  try {
    const messages: ChatMessage[] = [
      {
        role: 'user',
        content: message
      }
    ];

    const headers: any = {
      'Content-Type': 'application/json',
    };

    if (threadId) {
      headers['X-IBM-THREAD-ID'] = threadId;
    }

    const requestBody = {
      messages: messages,
      stream: false,
      additional_parameters: includeReasoning ? { include_reasoning: true } : undefined
    };

    const response = await wxoApi.post(
      `/v1/orchestrate/${agentId}/chat/completions`,
      requestBody,
      { headers }
    );

    // Extract response from the choices array
    const choice = response.data.choices?.[0];
    if (!choice) {
      throw new Error('No response from agent');
    }

    const content = choice.message?.content;
    let responseText = '';

    if (typeof content === 'string') {
      responseText = content;
    } else if (Array.isArray(content)) {
      // Extract text from content array
      responseText = content
        .filter((item: any) => item.response_type === 'text' && item.text)
        .map((item: any) => item.text)
        .join('\n');
    }

    return {
      response: responseText || 'No response text available',
      thread_id: response.data.thread_id || '',
      reasoning: choice.reasoning
    };
  } catch (error: any) {
    console.error('Chat error:', error.response?.data || error.message);
    throw new Error(`Failed to chat with agent: ${error.response?.data?.detail || error.message}`);
  }
}

/**
 * Query SAP Repository knowledge base
 * Main tool for querying SAP metadata, standards, and requirements
 */
server.tool(
  "query_sap_repo",
  {
    query: z.string().describe("Question or query about SAP metadata, standards, naming conventions, coding standards, modification rules, transport landscape, or business requirements"),
    thread_id: z.string().optional().describe("Thread ID to continue a conversation (optional)"),
    include_reasoning: z.boolean().optional().describe("Include agent reasoning in response (default: false)"),
  },
  async ({ query, thread_id, include_reasoning = false }) => {
    try {
      const result = await chatWithAgent(WXO_AGENT_ID, query, thread_id, include_reasoning);

      let resultText = result.response;
      
      // Add thread_id for conversation continuity
      if (result.thread_id) {
        resultText += `\n\n---\nThread ID: ${result.thread_id}`;
      }

      // Add reasoning if requested
      if (include_reasoning && result.reasoning) {
        resultText += `\n\n---\nReasoning:\n${JSON.stringify(result.reasoning, null, 2)}`;
      }

      return {
        content: [
          {
            type: "text",
            text: resultText,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `Error querying SAP Repository: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

/**
 * Get SAP table structure and field definitions
 */
server.tool(
  "get_sap_table_structure",
  {
    table_name: z.string().describe("SAP table name (e.g., MARA, VBAK, EKKO)"),
    include_fields: z.boolean().optional().describe("Include detailed field information (default: true)"),
  },
  async ({ table_name, include_fields = true }) => {
    try {
      const query = include_fields
        ? `Provide the structure and field definitions for SAP table ${table_name}. Include field names, data types, lengths, descriptions, and any key fields.`
        : `Provide a summary of SAP table ${table_name} including its purpose and key fields.`;

      const result = await chatWithAgent(WXO_AGENT_ID, query);

      return {
        content: [
          {
            type: "text",
            text: result.response,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `Error getting table structure: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

/**
 * Get SAP naming conventions for development objects
 */
server.tool(
  "get_sap_naming_conventions",
  {
    object_type: z.string().describe("Type of SAP object (e.g., program, function module, table, class, report)"),
    module: z.string().optional().describe("SAP module or package (e.g., MM, SD, FI, ZORD)"),
  },
  async ({ object_type, module }) => {
    try {
      const query = module
        ? `What are the naming conventions for ${object_type} in the ${module} module? Include prefix rules, length restrictions, and examples.`
        : `What are the naming conventions for ${object_type}? Include prefix rules, length restrictions, and examples.`;

      const result = await chatWithAgent(WXO_AGENT_ID, query);

      return {
        content: [
          {
            type: "text",
            text: result.response,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `Error getting naming conventions: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

/**
 * Get SAP coding standards and best practices
 */
server.tool(
  "get_sap_coding_standards",
  {
    topic: z.string().describe("Coding standard topic (e.g., performance, error handling, documentation, SQL, modularization)"),
    language: z.string().optional().describe("Programming language (e.g., ABAP, ABAP OO) - default: ABAP"),
  },
  async ({ topic, language = "ABAP" }) => {
    try {
      const query = `What are the ${language} coding standards and best practices for ${topic}? Include specific rules, examples, and anti-patterns to avoid.`;

      const result = await chatWithAgent(WXO_AGENT_ID, query);

      return {
        content: [
          {
            type: "text",
            text: result.response,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `Error getting coding standards: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

/**
 * Get SAP user exits and enhancement points
 */
server.tool(
  "get_sap_user_exits",
  {
    transaction: z.string().optional().describe("SAP transaction code (e.g., VA01, ME21N)"),
    program: z.string().optional().describe("SAP program name"),
    module: z.string().optional().describe("SAP module (e.g., MM, SD, FI)"),
    requirement: z.string().describe("Business requirement or functionality to enhance"),
  },
  async ({ transaction, program, module, requirement }) => {
    try {
      let query = `What user exits, BADIs, or enhancement points are available for: ${requirement}?`;
      
      if (transaction) {
        query += ` Transaction: ${transaction}.`;
      }
      if (program) {
        query += ` Program: ${program}.`;
      }
      if (module) {
        query += ` Module: ${module}.`;
      }
      
      query += " Include the exit name, type, and how to implement it.";

      const result = await chatWithAgent(WXO_AGENT_ID, query);

      return {
        content: [
          {
            type: "text",
            text: result.response,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `Error getting user exits: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

/**
 * Get SAP transport landscape and procedures
 */
server.tool(
  "get_transport_landscape",
  {
    query_type: z.enum(["overview", "procedure", "request_type", "troubleshooting"]).describe("Type of transport information needed"),
    details: z.string().optional().describe("Additional details or specific question about transports"),
  },
  async ({ query_type, details }) => {
    try {
      let query = "";
      
      switch (query_type) {
        case "overview":
          query = "Describe the SAP transport landscape structure (DEV, QAS, PRD) and the transport management process.";
          break;
        case "procedure":
          query = details 
            ? `What is the procedure for: ${details}?`
            : "What are the standard procedures for creating and releasing transport requests?";
          break;
        case "request_type":
          query = details
            ? `When should I use ${details} transport request type?`
            : "What are the different types of transport requests and when should each be used?";
          break;
        case "troubleshooting":
          query = details
            ? `How do I troubleshoot this transport issue: ${details}?`
            : "What are common transport issues and how to resolve them?";
          break;
      }

      const result = await chatWithAgent(WXO_AGENT_ID, query);

      return {
        content: [
          {
            type: "text",
            text: result.response,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `Error getting transport information: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("SAP Repository MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});

// Made with Bob
