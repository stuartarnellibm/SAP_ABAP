# Quick Test Guide

## Step 1: Install Dependencies

```bash
cd sap-repo-mcp
npm install
```

This will install:
- `@modelcontextprotocol/sdk` - MCP server framework
- `axios` - HTTP client for API calls
- `zod` - Schema validation
- `dotenv` - Environment variable management
- `typescript` - TypeScript compiler
- `@types/node` - Node.js type definitions

## Step 2: Test Authentication

Run the authentication test script:

```bash
node test-auth.js
```

**Expected output:**
```
🔍 Testing watsonx Orchestrate Authentication

Configuration:
  API URL: https://api.eu-central-1.dl.watson-orchestrate.ibm.com/instances/...
  Agent ID: SA_SAP_Repo_99901A
  API Key: azE6dXNyXzYxNzFkNzFh...

📋 Step 1: Parsing API key...
✅ Username: usr_6171d71a-2522-37d6-810f-519f6e38774f
✅ Password: tNiAH4w1CR...

📋 Step 2: Requesting access token...
✅ Access token received: eyJhbGciOiJSUzI1NiIsInR5cCI6...
✅ Token type: bearer

📋 Step 3: Testing agent chat API...
✅ Chat API response received
✅ Thread ID: 12345678-1234-1234-1234-123456789abc

📝 Agent Response:
────────────────────────────────────────────────────────────────────────────────
ABAP function modules follow these naming conventions:
1. Customer namespace: Z* or Y*
2. Standard format: Z<MODULE>_<FUNCTION>
...
────────────────────────────────────────────────────────────────────────────────

✅ All tests passed! Authentication is working correctly.

🎉 Your MCP server is ready to use!
```

## Step 3: Build the MCP Server

```bash
npm run build
```

This compiles the TypeScript code to JavaScript in the `build/` directory.

## Step 4: Configure Bob

Add to `~/.bob/settings/mcp_settings.json`:

```json
{
  "mcpServers": {
    "sap-repo-mcp": {
      "command": "node",
      "args": [
        "/Users/stuart/git/SAP_ABAP/sap-repo-mcp/build/index.js"
      ],
      "env": {
        "WXO_API_URL": "https://api.eu-central-1.dl.watson-orchestrate.ibm.com/instances/20250610-0939-5420-70cd-263042dba86b",
        "WXO_API_KEY": "azE6dXNyXzYxNzFkNzFhLTI1MjItMzdkNi04MTBmLTUxOWY2ZTM4Nzc0Zjp0TmlBSDR3MUNSUkM0TzlGSVJINWYzM3l3ckhzb3ZENGIrS25IUGZXL2k4PTpHTDNj",
        "WXO_AGENT_ID": "SA_SAP_Repo_99901A"
      }
    }
  }
}
```

## Step 5: Restart Bob

Restart VS Code or reload the window to load the new MCP server.

## Step 6: Test with Bob

Try these queries in Bob:

1. **General query:**
   ```
   Query the SAP repo about naming conventions for function modules
   ```

2. **Table structure:**
   ```
   Get the structure of SAP table VBAK
   ```

3. **Coding standards:**
   ```
   What are the ABAP coding standards for error handling?
   ```

4. **User exits:**
   ```
   Find user exits for adding custom validation in VA01 order creation
   ```

5. **Transport info:**
   ```
   What is the procedure for creating a workbench transport request?
   ```

## Troubleshooting

### If test-auth.js fails:

**Error: "Invalid API key format"**
- Your API key might be corrupted
- Copy it again from watsonx Orchestrate Settings → API

**Error: "Authentication failed" (401)**
- Your credentials might have expired
- Regenerate your API key in watsonx Orchestrate

**Error: "Failed to chat with agent"**
- Verify the agent exists: `orchestrate agents list | grep Repo`
- Check the agent name matches `SA_SAP_Repo_99901A`

**Error: "Cannot find module"**
- Run `npm install` again
- Check that `node_modules/` directory exists

### If Bob doesn't see the MCP server:

1. Check the path in `mcp_settings.json` is absolute
2. Verify `build/index.js` exists (run `npm run build`)
3. Check the Bob logs for errors
4. Restart VS Code completely

## Manual Testing

You can also test the MCP server directly:

```bash
# Run the server
node build/index.js

# It should output:
# SAP Repository MCP Server running on stdio
```

Press Ctrl+C to stop.

## Success Indicators

✅ `test-auth.js` completes without errors
✅ `npm run build` creates `build/index.js`
✅ Bob shows "sap-repo-mcp" in available MCP servers
✅ Bob can use the `query_sap_repo` tool
✅ You get responses from the SAP Repository agent

## Next Steps

Once everything works:
1. Read `SETUP_GUIDE.md` for detailed documentation
2. Try all 6 available tools
3. Use threading for multi-turn conversations
4. Integrate into your SAP development workflow