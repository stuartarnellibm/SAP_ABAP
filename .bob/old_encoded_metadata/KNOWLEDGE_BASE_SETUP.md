# Knowledge Base Setup Guide for SAP Metadata

This guide explains how to create and use a knowledge base with Bob to enable metadata-driven SAP development.

## What is a Knowledge Base?

A knowledge base allows Bob to:
- Query structured information using natural language
- Access metadata without reading files repeatedly
- Provide context-aware recommendations
- Scale to large volumes of metadata

## Option 1: Using watsonx Orchestrate (Recommended for Enterprise)

### Prerequisites
- watsonx Orchestrate account
- MCP (Model Context Protocol) server access
- Bob configured with watsonx Orchestrate MCP

### Setup Steps

#### 1. Create Knowledge Base in watsonx Orchestrate

```bash
# Access watsonx Orchestrate console
# Navigate to: Knowledge Bases → Create New
```

**Configuration:**
- **Name**: SAP_CPG_Metadata
- **Description**: SAP R/3 metadata for CPG Order-to-Cash and Warehouse Management
- **Type**: Structured Data
- **Source**: File Upload or API

#### 2. Prepare Metadata for Upload

Convert JSON files to knowledge base format:

```json
{
  "documents": [
    {
      "id": "sap_table_vbak",
      "title": "SAP Table VBAK - Sales Document Header",
      "content": "VBAK is the sales document header table in SAP SD module...",
      "metadata": {
        "object_type": "table",
        "module": "SD",
        "modification_allowed": false,
        "key_fields": ["MANDT", "VBELN"]
      }
    },
    {
      "id": "naming_convention_programs",
      "title": "Naming Convention for ABAP Programs",
      "content": "Pattern: ZCPG_<MODULE>_<PURPOSE>. Examples: ZCPG_SD_ORDER_DASHBOARD...",
      "metadata": {
        "category": "standards",
        "type": "naming_convention"
      }
    }
  ]
}
```

#### 3. Upload to Knowledge Base

```bash
# Using watsonx Orchestrate API
curl -X POST https://api.watsonx.ibm.com/v1/knowledge-bases/SAP_CPG_Metadata/documents \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d @sap_metadata_kb.json
```

#### 4. Configure Bob to Use Knowledge Base

In your Bob mode configuration (`.bob/modes/ulsapdeveng/mode.json`):

```json
{
  "name": "Unilever SAP Delivery Engineer",
  "slug": "ulsapdeveng",
  "instructions": "You are an SAP development expert...",
  "knowledge_bases": [
    {
      "id": "SAP_CPG_Metadata",
      "provider": "watsonx_orchestrate",
      "priority": "high"
    }
  ],
  "tools": ["read_file", "write_to_file", "execute_command"]
}
```

#### 5. Query Knowledge Base from Bob

Bob can now query using natural language:

```
User: "What are the key fields for VBAK table?"
Bob: [Queries knowledge base] → Returns: MANDT, VBELN

User: "What's the naming convention for SD programs?"
Bob: [Queries knowledge base] → Returns: ZCPG_SD_<PURPOSE>

User: "Can I modify the VBAP table?"
Bob: [Queries knowledge base] → Returns: No, use CI includes or Z-tables
```

## Option 2: Using Local Vector Database (Alternative)

### Prerequisites
- Python 3.8+
- ChromaDB or similar vector database
- Bob with MCP server capability

### Setup Steps

#### 1. Install Dependencies

```bash
pip install chromadb sentence-transformers
```

#### 2. Create Vector Database

```python
# create_sap_kb.py
import chromadb
import json
from pathlib import Path

# Initialize ChromaDB
client = chromadb.Client()
collection = client.create_collection(name="sap_metadata")

# Load metadata files
metadata_dir = Path(".bob/metadata")

# Process tables
with open(metadata_dir / "sap_objects/tables.json") as f:
    tables_data = json.load(f)
    
for category, data in tables_data.get("table_categories", {}).items():
    for table in data.get("tables", []):
        collection.add(
            documents=[json.dumps(table)],
            metadatas=[{"type": "table", "module": table.get("module")}],
            ids=[f"table_{table['name']}"]
        )

# Process standards
with open(metadata_dir / "standards/naming_conventions.json") as f:
    naming_data = json.load(f)
    
collection.add(
    documents=[json.dumps(naming_data)],
    metadatas=[{"type": "standard", "category": "naming"}],
    ids=["naming_conventions"]
)

print("Knowledge base created successfully!")
```

#### 3. Create MCP Server

```python
# sap_kb_mcp_server.py
from mcp.server import Server
import chromadb

app = Server("sap-metadata-kb")
client = chromadb.Client()
collection = client.get_collection("sap_metadata")

@app.list_resources()
async def list_resources():
    return [
        {
            "uri": "kb://sap_metadata/tables",
            "name": "SAP Tables Metadata",
            "mimeType": "application/json"
        },
        {
            "uri": "kb://sap_metadata/standards",
            "name": "Development Standards",
            "mimeType": "application/json"
        }
    ]

@app.read_resource()
async def read_resource(uri: str):
    if "tables" in uri:
        results = collection.query(
            query_texts=["tables"],
            where={"type": "table"},
            n_results=100
        )
        return {"contents": [{"uri": uri, "text": str(results)}]}
    
    elif "standards" in uri:
        results = collection.query(
            query_texts=["standards"],
            where={"type": "standard"},
            n_results=100
        )
        return {"contents": [{"uri": uri, "text": str(results)}]}

@app.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "query_sap_metadata":
        query = arguments.get("query")
        results = collection.query(
            query_texts=[query],
            n_results=5
        )
        return {"content": [{"type": "text", "text": str(results)}]}

if __name__ == "__main__":
    app.run()
```

#### 4. Configure Bob MCP

In `.bob/mcp.json`:

```json
{
  "mcpServers": {
    "sap-metadata-kb": {
      "command": "python",
      "args": ["sap_kb_mcp_server.py"],
      "env": {}
    }
  }
}
```

## Option 3: Using File-Based Approach (Current - Simplest)

### Current Implementation

Bob reads metadata files directly using `read_file` tool:

```
User: "What are the fields in VBAK?"
Bob: <read_file>
     <args>
       <file>
         <path>.bob/metadata/sap_objects/tables.json</path>
       </file>
     </args>
     </read_file>
```

### Advantages
- ✅ Simple setup (already done!)
- ✅ No additional infrastructure
- ✅ Version controlled with Git
- ✅ Easy to update and maintain

### Disadvantages
- ❌ Slower for large metadata sets
- ❌ Requires Bob to know file locations
- ❌ No semantic search capability

## Recommended Approach

### For Your Current Setup: File-Based (Option 3)

**Why:**
1. Metadata is already structured in JSON files
2. No additional infrastructure needed
3. Easy to maintain and version control
4. Sufficient for current metadata volume

**How to Use:**

#### 1. Update Your Mode Instructions

Edit `.bob/modes/ulsapdeveng/mode.json`:

```json
{
  "instructions": "You are an SAP development expert. 

IMPORTANT: Before making any SAP development decisions, consult the metadata in .bob/metadata/:

- SAP Objects: .bob/metadata/sap_objects/ (tables, functions, programs, user exits)
- Standards: .bob/metadata/standards/ (naming, coding, packages)
- Transport Landscape: .bob/metadata/transport_landscape/
- Modification Rules: .bob/metadata/modification_rules/
- Fit-Gap Analysis: .bob/metadata/fit_gap/

Always read relevant metadata files before:
- Creating new objects (check naming conventions)
- Modifying SAP standard (check modification rules)
- Using tables or functions (check object metadata)
- Planning implementations (check fit-gap analysis)

Use read_file tool to access metadata as needed."
}
```

#### 2. Create Helper Skill (Optional)

Create `.bob/skills/sap-metadata-advisor/skill.json`:

```json
{
  "name": "SAP Metadata Advisor",
  "description": "Provides SAP metadata guidance",
  "instructions": "When asked about SAP objects, standards, or requirements:
  
1. Read relevant metadata from .bob/metadata/
2. Provide specific guidance based on metadata
3. Reference exact file locations
4. Quote relevant sections

Example queries:
- 'What are the fields in VBAK?' → Read .bob/metadata/sap_objects/tables.json
- 'What's the naming convention for programs?' → Read .bob/metadata/standards/naming_conventions.json
- 'Can I modify VBAP?' → Read .bob/metadata/modification_rules/standard_objects.json"
}
```

### Migration Path to Knowledge Base (Future)

When metadata grows significantly:

1. **Phase 1** (Current): File-based approach ✅
2. **Phase 2** (6-12 months): Add vector database for semantic search
3. **Phase 3** (12+ months): Migrate to enterprise knowledge base (watsonx)

## Usage Examples

### Example 1: Check Table Metadata

```
User: "I need to read sales order data. What table should I use?"

Bob: Let me check the SAP tables metadata.
<read_file>
  <args>
    <file>
      <path>.bob/metadata/sap_objects/tables.json</path>
    </file>
  </args>
</read_file>

Based on the metadata, use:
- VBAK for header data (key fields: MANDT, VBELN)
- VBAP for item data (key fields: MANDT, VBELN, POSNR)
- Never SELECT *, always specify fields
- Use INNER JOIN instead of nested SELECTs
```

### Example 2: Validate Naming Convention

```
User: "I want to create a program for order dashboard. What should I name it?"

Bob: Let me check the naming conventions.
<read_file>
  <args>
    <file>
      <path>.bob/metadata/standards/naming_conventions.json</path>
    </file>
  </args>
</read_file>

Based on naming conventions:
Pattern: ZCPG_<MODULE>_<PURPOSE>
Your program should be: ZCPG_SD_ORDER_DASHBOARD

This follows the standard where:
- Z = Customer namespace
- CPG = Company identifier
- SD = Sales & Distribution module
- ORDER_DASHBOARD = Clear purpose
```

### Example 3: Check Modification Rules

```
User: "Can I add a field to VBAP table?"

Bob: Let me check the modification rules.
<read_file>
  <args>
    <file>
      <path>.bob/metadata/modification_rules/standard_objects.json</path>
    </file>
  </args>
</read_file>

NO - Direct modification of VBAP is PROHIBITED.

Alternatives:
1. Use CI_VBAP_APPEND include for custom fields
2. Create ZCPG_ORDER_ITEM_EXT table with VBELN+POSNR as foreign key
3. Use user exits for custom logic

Reason: Standard table modifications break upgrade path.
```

## Maintenance

### Updating Metadata

```bash
# 1. Edit metadata files
vi .bob/metadata/sap_objects/tables.json

# 2. Commit changes
git add .bob/metadata/
git commit -m "Updated VBAK table metadata"

# 3. Bob automatically uses latest version
```

### Adding New Metadata

```bash
# Create new metadata file
vi .bob/metadata/sap_objects/custom_tables.json

# Update README.md to reference new file
vi .bob/metadata/README.md
```

## Best Practices

1. **Keep metadata up-to-date**: Update after each SAP change
2. **Use consistent structure**: Follow JSON schema patterns
3. **Document changes**: Add change history in files
4. **Version control**: Commit metadata with code changes
5. **Review regularly**: Quarterly metadata review
6. **Start simple**: Use file-based approach, migrate to KB when needed

## Troubleshooting

### Bob not finding metadata
- Check file paths in mode instructions
- Verify files exist in .bob/metadata/
- Ensure JSON is valid

### Metadata too large
- Split into smaller files
- Use line ranges in read_file
- Consider vector database

### Need semantic search
- Implement Option 2 (ChromaDB)
- Or migrate to Option 1 (watsonx)

## Summary

**Current Recommendation**: Use file-based approach (Option 3)
- ✅ Already implemented
- ✅ Simple and maintainable
- ✅ Sufficient for current needs

**Future Enhancement**: Migrate to knowledge base when:
- Metadata exceeds 100+ files
- Need semantic search
- Multiple teams accessing metadata
- Integration with other systems required