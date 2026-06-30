# SAP Repository MCP Server

MCP (Model Context Protocol) server that provides access to the SAP Repository knowledge base through watsonx Orchestrate REST API.

## Overview

This MCP server exposes SAP metadata, coding standards, naming conventions, and business requirements from the watsonx Orchestrate SAP Repository knowledge base. It provides a RESTful interface alternative to the ADK-based approach.

## Features

### Available Tools

1. **query_sap_repo** - General purpose query tool
   - Query any SAP metadata, standards, or requirements
   - Supports conversation threading
   - Optional reasoning output

2. **get_sap_table_structure** - Table structure queries
   - Get field definitions for SAP tables
   - Includes data types, key fields, and foreign keys
   - Optimized for table metadata retrieval

3. **get_sap_naming_conventions** - Naming standards
   - Retrieve naming conventions for SAP objects
   - Supports functional area filtering (O2C, WM, FI, MM)
   - Includes examples and structure requirements

4. **get_sap_coding_standards** - Coding best practices
   - Performance guidelines
   - Error handling standards
   - SQL optimization rules
   - Documentation requirements

5. **get_sap_user_exits** - User exit discovery
   - Find available user exits for transactions
   - Includes BADIs and enhancement points
   - Provides usage examples

6. **get_transport_landscape** - Transport information
   - Transport landscape overview
   - Promotion procedures
   - Request types and usage
   - Path to production

## Prerequisites

- Node.js 18+ and npm
- Access to watsonx Orchestrate instance
- API credentials for watsonx Orchestrate
- SAP Repository agent (SA_SAP_Repo_99901A) deployed in watsonx Orchestrate

## Installation

### 1. Install Dependencies

```bash
cd sap-repo-mcp
npm install
```

### 2. Build the Server

```bash
npm run build
```

This compiles the TypeScript code to JavaScript in the `build/` directory and makes `build/index.js` executable.

### 3. Get watsonx Orchestrate Credentials

You need the following information from your watsonx Orchestrate instance:

1. **API URL**: The base URL for your watsonx Orchestrate REST API
   - Format: `https://your-instance.watsonx-orchestrate.ibm.com/api/v1`
   - Contact your watsonx Orchestrate administrator for the exact URL

2. **API Key**: Authentication token for the REST API
   - Generate from watsonx Orchestrate console
   - Navigate to: Settings → API Keys → Generate New Key
   - Store securely - this key provides full access to your agents

3. **Agent ID** (optional): The specific agent ID to query
   - Default: `SA_SAP_Repo_99901A`
   - Can be customized if you have a different agent name

### 4. Configure MCP Settings

Add the server configuration to your MCP settings file at:
`~/.bob/settings/mcp_settings.json`

```json
{
  "mcpServers": {
    "sap-repo": {
      "command": "node",
      "args": ["/Users/stuart/git/SAP_ABAP/sap-repo-mcp/build/index.js"],
      "env": {
        "WXO_API_URL": "https://your-instance.watsonx-orchestrate.ibm.com/api/v1",
        "WXO_API_KEY": "your-api-key-here",
        "WXO_AGENT_ID": "SA_SAP_Repo_99901A"
      },
      "disabled": false,
      "alwaysAllow": [],
      "disabledTools": []
    }
  }
}
```

**Important**: Replace the placeholder values:
- `WXO_API_URL`: Your actual watsonx Orchestrate API endpoint
- `WXO_API_KEY`: Your generated API key
- `WXO_AGENT_ID`: Your agent ID (or keep default)

## Usage Examples

### Example 1: Query SAP Table Structure

```typescript
// Using the get_sap_table_structure tool
{
  "table_name": "VBAK",
  "include_fields": true
}

// Response includes:
// - Field names and data types
// - Key fields
// - Foreign key relationships
// - Field descriptions
```

### Example 2: Get Naming Conventions

```typescript
// Using the get_sap_naming_conventions tool
{
  "object_type": "function_module",
  "functional_area": "O2C"
}

// Response includes:
// - Prefix requirements (Z_SD_, Z_O2C_)
// - Structure patterns
// - Length limits
// - Examples
```

### Example 3: Query Coding Standards

```typescript
// Using the get_sap_coding_standards tool
{
  "topic": "performance"
}

// Response includes:
// - Performance rules
// - SQL optimization guidelines
// - Anti-patterns to avoid
// - Best practices
```

### Example 4: Find User Exits

```typescript
// Using the get_sap_user_exits tool
{
  "transaction_or_process": "Warehouse Management"
}

// Response includes:
// - Available user exits (LM01UXX, LM02UXX, etc.)
// - BADIs (LE_WM_TO_CREATE, LE_WM_PUTAWAY)
// - When they are called
// - Typical use cases
```

### Example 5: General Query with Threading

```typescript
// Using the query_sap_repo tool
{
  "query": "What are the fields in table KNA1?",
  "include_reasoning": false
}

// First response includes thread_id
// Use thread_id for follow-up questions:
{
  "query": "What about KNVV?",
  "thread_id": "previous-thread-id-here"
}
```

## API Endpoint Structure

The server expects the watsonx Orchestrate REST API to have the following endpoint:

```
POST {WXO_API_URL}/chat
```

### Request Format

```json
{
  "agent_id": "SA_SAP_Repo_99901A",
  "message": "Your query here",
  "thread_id": "optional-thread-id",
  "include_reasoning": false
}
```

### Response Format

```json
{
  "response": "Agent response text",
  "thread_id": "conversation-thread-id",
  "reasoning": "optional reasoning trace",
  "thinking_trace": [],
  "error": "optional error message"
}
```

## Configuration Options

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| WXO_API_URL | Yes | - | watsonx Orchestrate API base URL |
| WXO_API_KEY | Yes | - | API authentication key |
| WXO_AGENT_ID | No | SA_SAP_Repo_99901A | Agent ID to query |

### MCP Settings Options

| Option | Type | Description |
|--------|------|-------------|
| disabled | boolean | Set to true to disable the server |
| timeout | number | Request timeout in seconds (default: 60) |
| alwaysAllow | string[] | Tools that don't require confirmation |
| disabledTools | string[] | Tools to exclude from system prompt |

## Troubleshooting

### Server Won't Start

**Error**: `WXO_API_URL environment variable is required`
- **Solution**: Ensure the environment variable is set in mcp_settings.json

**Error**: `Cannot find module '@modelcontextprotocol/sdk'`
- **Solution**: Run `npm install` in the sap-repo-mcp directory

### API Connection Issues

**Error**: `watsonx Orchestrate API error: 401 Unauthorized`
- **Solution**: Verify your API key is correct and not expired

**Error**: `watsonx Orchestrate API error: 404 Not Found`
- **Solution**: Check that WXO_API_URL is correct and includes `/api/v1`

**Error**: `Agent 'SA_SAP_Repo_99901A' not found`
- **Solution**: Verify the agent is deployed in your watsonx Orchestrate instance

### Timeout Issues

**Error**: Request timeout after 120 seconds
- **Solution**: Complex queries may take longer. The timeout is set to 2 minutes.
- **Workaround**: Break complex queries into smaller, more specific questions

## Development

### Project Structure

```
sap-repo-mcp/
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── README.md            # This file
├── src/
│   └── index.ts         # Main server implementation
└── build/               # Compiled JavaScript (generated)
    └── index.js         # Executable server
```

### Building

```bash
npm run build
```

### Watching for Changes

```bash
npm run watch
```

### Adding New Tools

To add a new tool, edit `src/index.ts` and add a new `server.tool()` call:

```typescript
server.tool(
  "tool_name",
  {
    param1: z.string().describe("Parameter description"),
  },
  async ({ param1 }) => {
    // Tool implementation
    const query = `Your query using ${param1}`;
    const requestBody: ChatRequest = {
      agent_id: WXO_AGENT_ID,
      message: query,
    };
    const response = await wxoApi.post<ChatResponse>('/chat', requestBody);
    return {
      content: [{ type: "text", text: response.data.response }],
    };
  }
);
```

## Security Considerations

1. **API Key Storage**: Never commit API keys to version control
2. **Environment Variables**: Store credentials in mcp_settings.json only
3. **Access Control**: API key provides full access to watsonx Orchestrate
4. **Network Security**: Ensure HTTPS is used for all API calls
5. **Key Rotation**: Regularly rotate API keys

## Performance

- **Typical Response Time**: 2-5 seconds for simple queries
- **Complex Queries**: 10-30 seconds for detailed analysis
- **Timeout**: 120 seconds (2 minutes)
- **Concurrent Requests**: Handled by watsonx Orchestrate backend

## Comparison with ADK Approach

| Feature | MCP Server (REST) | ADK Approach |
|---------|------------------|--------------|
| Dependencies | Minimal (axios, zod) | Full ADK package |
| Authentication | API Key | ADK credentials |
| Flexibility | High (any REST client) | ADK-specific |
| Maintenance | Independent | Coupled to ADK |
| Performance | Direct REST calls | ADK abstraction layer |

## Support

For issues or questions:
- Check the troubleshooting section above
- Review watsonx Orchestrate API documentation
- Verify agent deployment in watsonx Orchestrate console
- Check MCP server logs in Bob's output

## License

MIT

## Version History

### 0.1.0 (2026-06-18)
- Initial release
- Six core tools for SAP metadata queries
- REST API integration with watsonx Orchestrate
- Conversation threading support
- Comprehensive error handling