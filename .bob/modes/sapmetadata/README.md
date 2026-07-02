# 🔍 SAP Metadata Query Mode

A specialized Bob mode for querying SAP R/3 metadata quickly and accurately.

## Purpose

This mode enables fast, read-only queries of SAP metadata including:
- SAP objects (tables, functions, programs, user exits)
- Development standards (naming, coding, packages)
- Modification rules (standard and custom)
- Business requirements (O2C and WM fit-gap)
- Transport landscape configuration

## When to Use This Mode

Use **SAP Metadata Query** mode when you need to:
- ✅ Look up SAP table fields and metadata
- ✅ Find function modules or BAPIs
- ✅ Check naming conventions
- ✅ Verify modification rules
- ✅ Review coding standards
- ✅ Query fit-gap requirements
- ✅ Check transport landscape configuration

**Do NOT use this mode for:**
- ❌ Creating or modifying code
- ❌ Making changes to files
- ❌ Executing commands
- ❌ Development tasks (use `ulsapdeveng` mode instead)

## How to Activate

```bash
# In Bob interface, switch to this mode:
/mode sapmetadata
```

Or click the mode selector and choose "🔍 SAP Metadata Query"

## Example Queries

### Query SAP Tables

```
Q: What are the key fields for VBAK?
A: [Reads .bob/metadata/sap_objects/tables.json]
   VBAK key fields:
   - MANDT (Client)
   - VBELN (Sales Document Number)
   
   Important fields:
   - ERDAT (Created On)
   - KUNNR (Customer)
   - VKORG (Sales Organization)
   - NETWR (Net Value)
```

```
Q: What tables are used for delivery processing?
A: [Reads .bob/metadata/sap_objects/tables.json]
   Delivery tables:
   - LIKP (Delivery Header)
   - LIPS (Delivery Items)
   - VBFA (Document Flow)
```

### Query Function Modules

```
Q: How do I create a sales order using BAPI?
A: [Reads .bob/metadata/sap_objects/function_modules.json]
   Use BAPI_SALESORDER_CREATEFROMDAT2
   
   Key parameters:
   - ORDER_HEADER_IN (header data)
   - ORDER_ITEMS_IN (line items)
   - RETURN (error messages)
   
   Always call BAPI_TRANSACTION_COMMIT after success.
```

### Query Naming Conventions

```
Q: What should I name my warehouse management program?
A: [Reads .bob/metadata/standards/naming_conventions.json]
   Pattern: ZCPG_WM_<PURPOSE>
   
   Examples:
   - ZCPG_WM_PERFORMANCE_RPT
   - ZCPG_WM_SLOTTING_ANALYSIS
   - ZCPG_WM_LABOR_DASHBOARD
```

### Query Modification Rules

```
Q: Can I modify the VBAP table?
A: [Reads .bob/metadata/modification_rules/standard_objects.json]
   NO - Direct modification of VBAP is PROHIBITED.
   
   Alternatives:
   1. Use CI_VBAP_APPEND include for custom fields
   2. Create ZCPG_ORDER_ITEM_EXT table with foreign key
   3. Use user exits for custom logic
   
   Reason: Standard table modifications break upgrade path.
```

### Query Coding Standards

```
Q: What are the ABAP coding standards for database access?
A: [Reads .bob/metadata/standards/coding_standards.json]
   Database Access Rules:
   - Always specify field list (never SELECT *)
   - Always use WHERE clause
   - Use FOR ALL ENTRIES with INITIAL check
   - Prefer INNER JOIN over nested SELECTs
   - Consider database buffering
```

### Query Requirements

```
Q: What are the requirements for promotional pricing?
A: [Reads .bob/metadata/fit_gap/o2c_requirements.json]
   Requirement O2C-002-01: Promotional order processing
   
   Priority: Critical
   Fit-Gap: Gap (custom development needed)
   Effort: 30 days
   
   Business Rules:
   - Volume-based tiered pricing
   - Trade allowances at order level
   - Accrual posting to finance
   - Promotion eligibility validation
```

### Query Transport Landscape

```
Q: What's the transport route from DEV to PRD?
A: [Reads .bob/metadata/transport_landscape/dev_config.json]
   Transport Route: DEV (CPD) → QAS (CPQ) → PRD (CPP)
   
   Process:
   1. Develop in CPD
   2. Auto-import to CPQ (daily at 02:00 AM)
   3. Test in QAS
   4. Manual import to CPP (release window: Sat 20:00-Sun 06:00)
```

## Quick Command Reference

| Command | Description | Metadata File |
|---------|-------------|---------------|
| `table` | Query table metadata | sap_objects/tables.json |
| `function` | Query function modules | sap_objects/function_modules.json |
| `program` | Query programs/transactions | sap_objects/programs.json |
| `exit` | Query user exits/BADIs | sap_objects/user_exits.json |
| `naming` | Query naming conventions | standards/naming_conventions.json |
| `coding` | Query coding standards | standards/coding_standards.json |
| `package` | Query package structure | standards/package_structure.json |
| `modify` | Query modification rules | modification_rules/*.json |
| `requirement` | Query fit-gap requirements | fit_gap/*.json |
| `transport` | Query transport landscape | transport_landscape/*.json |

## Response Format

Every response includes:

1. **Direct Answer**: The specific information requested
2. **Context**: Why/how it's used in SAP
3. **Related Info**: Related objects or considerations
4. **Examples**: Practical examples from metadata
5. **Source Reference**: Exact metadata file location

## Metadata Categories

### 1. SAP Objects
- **Tables**: Structure, fields, keys, relationships
- **Functions**: BAPIs, function modules, parameters
- **Programs**: Reports, transactions, usage
- **User Exits**: Enhancements, BADIs, implementation

### 2. Development Standards
- **Naming**: Conventions for all object types
- **Coding**: ABAP best practices and guidelines
- **Packages**: Organization and structure

### 3. Modification Rules
- **Standard Objects**: What can/cannot be modified
- **Custom Objects**: Development guidelines

### 4. Business Requirements
- **O2C**: Order-to-Cash fit-gap analysis
- **WM**: Warehouse Management fit-gap analysis

### 5. Transport Landscape
- **DEV**: Development system configuration
- **QAS**: Quality Assurance configuration
- **PRD**: Production system configuration

## Tips for Effective Queries

### Be Specific
❌ "Tell me about sales orders"
✅ "What are the key fields in VBAK table?"

### Ask One Thing at a Time
❌ "What are all the tables, functions, and standards for sales orders?"
✅ "What tables are used for sales order processing?"

### Use SAP Terminology
✅ "What's the BAPI for creating sales orders?"
✅ "What user exits are available in MV45AFZZ?"
✅ "What's the naming convention for ABAP programs?"

### Follow-up Questions Welcome
After getting an answer, you can ask:
- "What are the related tables?"
- "Show me an example"
- "What are the alternatives?"
- "Where can I find more information?"

## Switching Modes

When you need to do more than query:

```bash
# Switch to development mode for coding
/mode ulsapdeveng

# Switch to architecture mode for design
/mode ulsaparchitect

# Switch back to metadata query
/mode sapmetadata
```

## Limitations

This mode is **READ-ONLY**:
- ✅ Can read metadata files
- ✅ Can search and list files
- ✅ Can ask follow-up questions
- ❌ Cannot create files
- ❌ Cannot modify files
- ❌ Cannot execute commands
- ❌ Cannot write code

## Metadata Sources

All information comes from:
```
.bob/metadata/
├── sap_objects/          # SAP object metadata
├── transport_landscape/  # System configurations
├── modification_rules/   # Development rules
├── standards/           # Coding and naming standards
└── fit_gap/             # Business requirements
```

## Keeping Metadata Current

The metadata is maintained by the SAP development team. If you find:
- Missing information
- Outdated metadata
- Incorrect data

Please notify the team to update the metadata files.

## Related Documentation

- [Metadata Repository README](.bob/metadata/README.md)
- [Knowledge Base Setup Guide](.bob/metadata/KNOWLEDGE_BASE_SETUP.md)
- [SAP Objects Metadata](.bob/metadata/sap_objects/)
- [Development Standards](.bob/metadata/standards/)

## Support

For questions about:
- **This mode**: Contact SAP Development Team
- **Metadata content**: Contact module leads (SD/MM/WM/LE)
- **Bob functionality**: Refer to Bob documentation

---

**Version**: 1.0.0  
**Last Updated**: 2026-06-17  
**Maintained By**: SAP Development Team