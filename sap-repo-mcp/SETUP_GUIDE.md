# SAP Repository MCP Server - Setup Guide

## Overview

This MCP server provides access to the SAP Repository knowledge base in watsonx Orchestrate through a REST API interface. It uses proper OAuth2 authentication with username/password credentials.

## Authentication Flow

The server implements the following authentication flow:

1. **API Key Format**: Your API key is a base64-encoded string containing:
   ```
   k1:username:password:extra_data
   ```

2. **Token Exchange**: On startup and when tokens expire, the server:
   - Decodes the API key to extract username and password
   - Calls `POST /v1/auth/token` with form-encoded credentials
   - Receives a Bearer token valid for ~1 hour
   - Caches the token and refreshes automatically

3. **API Calls**: All subsequent API calls use:
   ```
   Authorization: Bearer <access_token>
   ```

## Prerequisites

- Node.js 18 or higher
- npm or yarn
- Access to a watsonx Orchestrate instance
- API credentials from watsonx Orchestrate

## Installation

1. **Install dependencies**:
   ```bash
   cd sap-repo-mcp
   npm install
   ```

2. **Build the TypeScript code**:
   ```bash
   npm run build
   ```

## Configuration

### Step 1: Create .env file

Copy the example environment file:
```bash
cp .env.example .env
```

### Step 2: Configure your credentials

Edit `.env` and set your values:

```env
# Your watsonx Orchestrate instance URL
WXO_API_URL=https://api.eu-central-1.dl.watson-orchestrate.ibm.com/instances/YOUR_INSTANCE_ID

# Your base64-encoded API key
WXO_API_KEY=YOUR_BASE64_ENCODED_API_KEY

# Agent ID (usually SA_SAP_Repo_99901A)
WXO_AGENT_ID=SA_SAP_Repo_99901A
```

**Finding your credentials:**

1. **WXO_API_URL**: 
   - Log into your watsonx Orchestrate instance
   - Go to Settings → API
   - Copy the "Instance URL"
   - Example: `https://api.eu-central-1.dl.watson-orchestrate.ibm.com/instances/20250610-0939-5420-70cd-263042dba86b`

2. **WXO_API_KEY**:
   - In the same API settings page
   - Copy the "API Key" (it's already base64-encoded)
   - Example: `azE6dXNyXzYxNzFkNzFhLTI1MjItMzdkNi04MTBmLTUxOWY2ZTM4Nzc0Zjp0TmlBSDR3MUNSUkM0TzlGSVJINWYzM3l3ckhzb3ZENGIrS25IUGZXL2k4PTpHTDNj`

3. **WXO_AGENT_ID**:
   - Run: `orchestrate agents list | grep Repo`
   - Find the agent name (usually `SA_SAP_Repo_99901A`)

### Step 3: Configure Bob to use the MCP server

Add to your `~/.bob/settings/mcp_settings.json`:

```json
{
  "mcpServers": {
    "sap-repo-mcp": {
      "command": "node",
      "args": [
        "/absolute/path/to/sap-repo-mcp/build/index.js"
      ],
      "env": {
        "WXO_API_URL": "https://api.eu-central-1.dl.watson-orchestrate.ibm.com/instances/YOUR_INSTANCE_ID",
        "WXO_API_KEY": "YOUR_BASE64_ENCODED_API_KEY",
        "WXO_AGENT_ID": "SA_SAP_Repo_99901A"
      }
    }
  }
}
```

**Important**: Replace `/absolute/path/to/sap-repo-mcp` with the actual absolute path.

## Testing

### Test 1: Verify authentication

```bash
cd sap-repo-mcp
node build/index.js
```

You should see: `SAP Repository MCP Server running on stdio`

If you see authentication errors, check:
- Your API key is correct and base64-encoded
- Your instance URL is correct
- Your credentials haven't expired

### Test 2: Test with Bob

1. Restart Bob/VS Code to load the new MCP server
2. In Bob, try: "Query the SAP repo about naming conventions for function modules"
3. Bob should use the `query_sap_repo` tool

## Available Tools

The MCP server provides 6 specialized tools:

### 1. query_sap_repo
General-purpose query tool for any SAP metadata question.

**Parameters:**
- `query` (required): Your question about SAP
- `thread_id` (optional): Continue a conversation
- `include_reasoning` (optional): Show agent's reasoning

**Example:**
```
Query: "What are the naming conventions for Z programs in the ZORD package?"
```

### 2. get_sap_table_structure
Get structure and field definitions for SAP tables.

**Parameters:**
- `table_name` (required): SAP table name (e.g., MARA, VBAK)
- `include_fields` (optional): Include detailed field info (default: true)

**Example:**
```
Table: VBAK
Include fields: true
```

### 3. get_sap_naming_conventions
Get naming conventions for development objects.

**Parameters:**
- `object_type` (required): Type of object (program, function module, table, etc.)
- `module` (optional): SAP module or package (MM, SD, ZORD, etc.)

**Example:**
```
Object type: function module
Module: ZORD
```

### 4. get_sap_coding_standards
Get coding standards and best practices.

**Parameters:**
- `topic` (required): Topic (performance, error handling, documentation, etc.)
- `language` (optional): Programming language (default: ABAP)

**Example:**
```
Topic: error handling
Language: ABAP
```

### 5. get_sap_user_exits
Find user exits and enhancement points.

**Parameters:**
- `transaction` (optional): Transaction code (VA01, ME21N, etc.)
- `program` (optional): Program name
- `module` (optional): SAP module
- `requirement` (required): What you want to enhance

**Example:**
```
Transaction: VA01
Requirement: Add custom validation for order creation
```

### 6. get_transport_landscape
Get information about transport landscape and procedures.

**Parameters:**
- `query_type` (required): overview | procedure | request_type | troubleshooting
- `details` (optional): Additional details or specific question

**Example:**
```
Query type: procedure
Details: How to create a workbench transport request
```

## Troubleshooting

### Error: "Authentication failed"

**Cause**: Invalid credentials or expired token

**Solution**:
1. Verify your API key is correct
2. Check your instance URL
3. Try regenerating your API key in watsonx Orchestrate

### Error: "Cannot find module"

**Cause**: Dependencies not installed or not built

**Solution**:
```bash
cd sap-repo-mcp
npm install
npm run build
```

### Error: "Failed to chat with agent"

**Cause**: Agent not found or not accessible

**Solution**:
1. Verify the agent exists: `orchestrate agents list | grep Repo`
2. Check the agent name matches `WXO_AGENT_ID`
3. Ensure you have access to the agent

### Error: "Invalid API key format"

**Cause**: API key is not properly base64-encoded

**Solution**:
1. Copy the API key exactly as shown in watsonx Orchestrate
2. Don't decode or modify it
3. It should look like: `azE6dXNyXz...`

## Architecture

```
┌─────────────────┐
│      Bob        │
│   (VS Code)     │
└────────┬────────┘
         │ MCP Protocol (stdio)
         │
┌────────▼────────────────────────────────────┐
│     SAP Repository MCP Server               │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Token Management                    │  │
│  │  - Decode API key                    │  │
│  │  - Exchange for Bearer token         │  │
│  │  - Cache & auto-refresh              │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  6 Specialized Tools                 │  │
│  │  - query_sap_repo                    │  │
│  │  - get_sap_table_structure           │  │
│  │  - get_sap_naming_conventions        │  │
│  │  - get_sap_coding_standards          │  │
│  │  - get_sap_user_exits                │  │
│  │  - get_transport_landscape           │  │
│  └──────────────────────────────────────┘  │
└────────┬────────────────────────────────────┘
         │ HTTPS + Bearer Token
         │
┌────────▼────────────────────────────────────┐
│   watsonx Orchestrate REST API              │
│                                             │
│   POST /v1/auth/token                       │
│   POST /v1/orchestrate/{agent}/chat/...    │
└────────┬────────────────────────────────────┘
         │
┌────────▼────────────────────────────────────┐
│   SA_SAP_Repo_99901A Agent                  │
│   (SAP Knowledge Base)                      │
└─────────────────────────────────────────────┘
```

## Security Notes

1. **Never commit .env file**: It contains sensitive credentials
2. **Token caching**: Tokens are cached in memory only (not persisted)
3. **Auto-refresh**: Tokens refresh automatically before expiry
4. **Secure storage**: Store credentials in environment variables or secure vaults

## Development

### Running in development mode

```bash
npm run dev
```

### Building

```bash
npm run build
```

### Testing authentication manually

```bash
# Test token exchange
curl -X POST "${WXO_API_URL}/v1/auth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${USERNAME}&password=${PASSWORD}&grant_type=password"
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify your credentials are correct
3. Check the watsonx Orchestrate documentation
4. Review the server logs for detailed error messages

## License

See LICENSE file in the repository root.