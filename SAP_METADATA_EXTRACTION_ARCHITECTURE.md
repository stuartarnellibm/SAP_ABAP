# SAP Metadata Extraction Architecture for RAG Pipeline

## Overview

A comprehensive architecture for extracting SAP R/3 customization metadata from a highly customized estate (40,000+ exits) and loading it into a vector database for Retrieval-Augmented Generation (RAG) queries.

**Key Requirements:**
- Batch execution (weekly/monthly) — no real-time requirement
- Output format suitable for vector database embedding
- Rich metadata lineage — where each piece of metadata came from
- Support for cross-references between metadata objects
- Ability to prioritize metadata sources in future

---

## 1. Metadata Extraction Strategy

### Phase 1: Core ABAP Report-Based Extractor

Build a custom ABAP report that systematically extracts metadata from the SAP repository using standard SAP tables and function modules.

#### Key Metadata Sources

```abap
" Repository Objects
- TADIR        " Directory of Repository Objects
- TDEVC        " Packages
- DD02L/DD02T  " Tables/Views
- DD03L        " Table fields
- DD04L/DD04T  " Data elements
- DD06L/DD06T  " Domains
- TFDIR        " Function Module Directory
- TRDIR        " ABAP Programs
- TABL_EXTRAS  " Technical Settings

" Customization
- CMOD/SMOD    " User/SAP Enhancements
- MODSAP/MODACT " Modifications
- TBE14        " Enhancement spots
- BADI_IMPL    " BAdi Implementations
- TSTC         " Transaction codes
- TSTCT        " Transaction texts

" Cross-references
- CROSS        " Cross-reference tables
- WBCROSSGT    " Global cross-references
- TADIR        " Where-used relationships

" Custom Code Depth Analysis
- AGR_*        " Authorization objects
- E071/E070    " Transport objects
- SMODILOG     " Modification log
```

### Phase 2: Extraction Architecture

#### Chunk Data Structure

```abap
PROGRAM z_metadata_extractor.

" Modular extraction with resumability
DATA: gt_extract_control TYPE TABLE OF ty_control.

" Each extraction unit with metadata enrichment
TYPES: BEGIN OF ty_metadata_chunk,
         chunk_id        TYPE string,        " UUID
         source_type     TYPE string,        " 'TABLE','FUNCTION','EXIT','BADI'
         object_name     TYPE string,        " MARA, Z_CUSTOM_FM
         object_type     TYPE trobjtype,     " TABL, FUNC
         package         TYPE devclass,      " Package
         layer           TYPE string,        " 'SAP_BASIS','CUSTOM','MODIFIED'
         priority        TYPE i,             " For future ranking
         parent_objects  TYPE string_table,  " Dependencies
         child_objects   TYPE string_table,  " Dependents
         content_text    TYPE string,        " Flattened for embedding
         content_json    TYPE string,        " Structured metadata
         relationships   TYPE string,        " JSON of cross-refs
         extraction_ts   TYPE timestamp,
         hash            TYPE string,        " Detect changes
       END OF ty_metadata_chunk.
```

---

## 2. Extraction Format for Vector DB

### Chunking Strategy

Each chunk must be self-contained with rich metadata. The `embedding_text` field should be a natural-language description of the object, while `metadata` carries structured fields for filtering and lineage.

```json
{
  "chunk_id": "uuid-v4",
  "embedding_text": "TABLE MARA - Material Master General Data. Contains basic material information including material number, description, material type...",
  "metadata": {
    "source": {
      "system": "PRD",
      "client": "100",
      "extraction_date": "2025-01-15T10:30:00Z",
      "extraction_version": "1.0"
    },
    "object": {
      "name": "MARA",
      "type": "TABL",
      "package": "MARA",
      "layer": "SAP_BASIS",
      "is_custom": false,
      "is_modified": false,
      "priority": 100
    },
    "lineage": {
      "parent_objects": ["DD02L", "DOMAIN_MATNR"],
      "child_objects": ["MARC", "MAKT"],
      "used_in_programs": ["SAPMM03M", "Z_CUSTOM_MATERIAL_LOAD"],
      "used_in_functions": ["BAPI_MATERIAL_GET_DETAIL"],
      "enhanced_by": []
    },
    "relationships": {
      "tables_referenced": ["T001", "T024"],
      "enhancement_points": [],
      "exits": []
    },
    "technical": {
      "field_count": 153,
      "key_fields": ["MATNR"],
      "row_count_estimate": 5000000
    }
  },
  "content_hash": "sha256-hash"
}
```

---

## 3. Implementation Options

### Option A: Pure ABAP Solution (Recommended for R/3)

**Pros:**
- Native access to all SAP metadata
- No RFC security concerns
- Can run in background job
- Transactional consistency

**Cons:**
- Limited JSON/HTTP capabilities in older R/3
- May need file-based transfer

```
┌─────────────────────────────────────┐
│   SAP R/3 System                    │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Z_METADATA_EXTRACTOR Report  │  │
│  │  - Extraction modules        │  │
│  │  - Chunking logic            │  │
│  │  - JSON serialization        │  │
│  │  - File output (JSONL)       │  │
│  └──────────────┬───────────────┘  │
│                 │                   │
│                 ▼                   │
│  ┌──────────────────────────────┐  │
│  │ Application Server           │  │
│  │ /tmp/metadata_export/        │  │
│  │  - chunks_YYYYMMDD.jsonl     │  │
│  └──────────────┬───────────────┘  │
└─────────────────┼───────────────────┘
                  │
                  │ File transfer (SFTP/SCP)
                  │
                  ▼
┌─────────────────────────────────────┐
│  External Processing Layer          │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Python/Node.js Processor     │  │
│  │  - Read JSONL files          │  │
│  │  - Generate embeddings       │  │
│  │  - Upload to vector DB       │  │
│  └──────────────┬───────────────┘  │
│                 │                   │
│                 ▼                   │
│  ┌──────────────────────────────┐  │
│  │ Vector Database              │  │
│  │ (Pinecone/Weaviate/ChromaDB) │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Option B: Hybrid ABAP + IBM Cloud (Recommended IBM Delivery)

For IBM-delivered solutions, the external processing layer runs on **IBM Cloud** or **IBM Cloud Pak for Data**, using watsonx.ai for embeddings and IBM Cloud Databases for OpenSearch as the vector store.

```
┌─────────────────────────────────────┐
│   SAP R/3 System                    │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Z_METADATA_EXTRACTOR         │  │
│  │  - RFC-enabled function      │  │
│  │  - JSONL file output         │  │
│  └──────────────┬───────────────┘  │
└─────────────────┼───────────────────┘
                  │ SFTP / IBM Aspera
                  │
                  ▼
┌─────────────────────────────────────┐
│  IBM Cloud                          │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ IBM Cloud Functions / CE Job │  │
│  │  - Reads JSONL files         │  │
│  │  - Orchestrates pipeline     │  │
│  └──────────────┬───────────────┘  │
│                 │                   │
│                 ▼                   │
│  ┌──────────────────────────────┐  │
│  │ watsonx.ai Embeddings API    │  │
│  │  IBM Slate 125m (rtrvr)      │  │
│  │  - Generates 768-dim vectors │  │
│  └──────────────┬───────────────┘  │
│                 │                   │
│                 ▼                   │
│  ┌──────────────────────────────┐  │
│  │ IBM Cloud Databases          │  │
│  │ for OpenSearch               │  │
│  │  - Hybrid KNN + BM25 search  │  │
│  │  - Metadata filtering        │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

---

## 4. Data Modelling for RAG

### Document Structure Per Metadata Type

```json
// Function Module
{
  "type": "FUNCTION_MODULE",
  "embedding_text": "Function Module BAPI_MATERIAL_GET_DETAIL retrieves material master data. Import parameters include MATERIAL (material number), PLANT (optional). Export parameters include MATERIAL_GENERAL_DATA (structure BAPI_MARA). Used by programs: Z_MAT_SYNC, Z_MAT_UPLOAD. Called by: 156 programs. Enhanced by: Z_EXIT_001.",
  "metadata": {
    "priority": 90,
    "layer": "SAP_BASIS",
    "is_custom": false
  }
}

// User Exit
{
  "type": "USER_EXIT",
  "embedding_text": "User Exit EXIT_SAPMM03M_001 in enhancement MM03M_001 allows validation of material master data before save. Project: Z_MATERIAL_VAL. Implemented by: ZXMM01 (include). Called from: SAPMM03M program. Dependencies: MARA table, BAPI_MARA structure.",
  "metadata": {
    "priority": 95,
    "layer": "CUSTOM_ENHANCEMENT",
    "is_custom": true
  }
}

// Table
{
  "type": "TABLE",
  "embedding_text": "Table MARA - Material Master General Data. Contains 153 fields including MATNR (material number), MTART (material type), MEINS (base unit). Primary key: MATNR. Used by 1,234 programs. Foreign keys to: T001, T024, T006. Enhanced in: 3 custom programs.",
  "metadata": {
    "priority": 85,
    "layer": "SAP_BASIS",
    "is_custom": false,
    "row_count": 5000000
  }
}
```

---

## 5. Recommended Implementation Roadmap

### Overview: Bob-Accelerated Delivery

Using **IBM Bob** throughout the development lifecycle fundamentally changes what is achievable and when. Bob eliminates the traditional research-and-scaffold overhead that consumes the first half of most development sprints: architecture review, boilerplate generation, cross-reference lookups, unit test authoring, and documentation writing all happen in the same session as the code itself. The roadmap below reflects this acceleration.

**Assumptions:**
- Bob is used for all design, code generation, review, testing, and documentation
- One developer with SAP R/3 system access is available
- SAP system access for background job execution and file system output is pre-approved
- Vector DB and embedding service are selected before Sprint 1 begins

**Revised total calendar time: ~3 weeks** (vs. 8 weeks without Bob)

---

### Sprint 1 — Days 1–3: Architecture & Design (Bob-led)

**What Bob does in this sprint:**
- Generates the full chunk data structure and extraction class skeleton from a single prompt
- Produces the technical specification and CDD document for sign-off
- Identifies all relevant SAP repository tables and FM interfaces from its ABAP knowledge base
- Authors the control table DDL (`ZTAB_EXTRACT_CTRL`) and transport object list

**Deliverables by end of Day 3:**
- Signed-off technical design
- ABAP class skeleton `ZCL_METADATA_EXTRACTOR` with all method signatures
- Control table definition
- Transport request structure

> Without Bob: this phase alone would typically take 1–2 weeks of research, workshops, and document drafting.

---

### Sprint 2 — Days 4–7: ABAP Extractor — Core Object Types

Bob generates production-ready ABAP for each extraction module in a single session, then the developer runs, tests, and iterates with Bob reviewing output.

**Day 4 — Repository Objects (Tables, Views, Structures):**
- Bob generates `extract_tables( )`, `extract_views( )`, `extract_data_elements( )` methods
- Reads from `DD02L`, `DD03L`, `DD04L`, `DD06L`
- JSON serialisation with lineage metadata

**Day 5 — Programs, Function Modules, Classes:**
- Bob generates extraction of `TRDIR`, `TFDIR`, class/method metadata via `SEO*` tables
- Parameter interface extraction via `FUNCTION_IMPORT_INTERFACE`
- Where-used cross-references via `RS_EU_CROSSREF`

**Day 6 — Enhancements, Exits, BADIs, Modifications:**
- Bob generates extraction of `CMOD`, `SMOD`, `TBE14`, `BADI_IMPL`, `MODSAP`
- Enhancement project → implementation → include chain fully resolved
- Priority score calculation injected by Bob

**Day 7 — Integration, Background Job, File Output:**
- Bob generates the job scheduling wrapper, file write logic (JSONL output), and control table delta logic
- Bob authors the SM36 variant configuration and transport documentation

**Deliverables by end of Day 7:**
- All extraction modules coded and unit-tested
- Background job runnable in DEV
- JSONL output validated against chunk schema

> Without Bob: this phase would be Weeks 1–4 of traditional delivery.

---

### Sprint 3 — Days 8–10: Cross-Reference & Lineage Graph

**Day 8:**
- Bob generates cross-reference resolution logic using `CROSS`, `WBCROSSGT`, and `TADIR`
- Dependency graph built as parent/child arrays embedded in each chunk's JSON

**Day 9:**
- Bob generates the priority scoring algorithm (see Section 6)
- Enhancement hot-spot detection — objects with the highest number of exits/BADIs ranked automatically

**Day 10:**
- Bob generates ABAP unit tests for all extraction modules using `CL_ABAP_UNIT_ASSERT`
- Bob generates the technical test evidence document for QA sign-off

**Deliverables by end of Day 10:**
- Full lineage graph embedded in every chunk
- Unit test suite passing in system
- QA-ready test evidence document

> Without Bob: cross-reference work and test authoring would be Weeks 5–6.

---

### Sprint 4 — Days 11–14: External Pipeline & RAG Validation

**Day 11 — Python Ingestion Pipeline:**
- Bob generates the full Python script: read JSONL → compute embeddings → upsert to vector DB
- Handles batching, retry logic, hash-based delta detection, and structured logging

**Day 12 — Vector DB Schema & RAG Query Layer:**
- Bob generates the vector DB index schema with all metadata fields
- Bob generates the RAG query interface with filter templates (by layer, priority, package, `is_modified`)
- Bob generates the LangChain retrieval chain wiring

**Day 13 — End-to-End Validation:**
- First full extraction run on DEV system
- Embeddings generated and loaded into vector DB
- Sample RAG queries validated against known metadata
- Bob generates the validation report

**Day 14 — Hardening & Runbook:**
- Bob generates the operational runbook (job scheduling, monitoring, re-run procedures)
- Bob generates handover documentation and Architecture Decision Records (ADRs)
- Pipeline scheduled for first production run

**Deliverables by end of Day 14:**
- Production-ready pipeline deployed
- Operational runbook and ADRs signed off
- First production extraction scheduled

> Without Bob: this phase would be Weeks 7–8 with documentation typically deferred or incomplete.

---

### Revised Timeline Summary

| Phase | Without Bob | With Bob | Saving |
|-------|------------|----------|--------|
| Architecture & Design | 1–2 weeks | 3 days | ~70% |
| ABAP Extractor (core objects) | 2 weeks | 4 days | ~70% |
| Cross-reference & lineage | 1 week | 2 days | ~70% |
| Unit testing & QA evidence | 1 week | 1 day | ~80% |
| External pipeline & RAG | 2 weeks | 4 days | ~65% |
| Documentation & runbook | Ongoing/deferred | Concurrent, same session | ~90% |
| **Total** | **~8 weeks** | **~3 weeks** | **~65%** |

> The largest savings come from documentation, boilerplate generation, and cross-referencing SAP system tables — tasks where Bob's SAP knowledge base eliminates almost all research time.

---

### What Bob Does at Each Stage

| Activity | Bob's Role |
|----------|-----------|
| Technical design | Generates CDD/spec from a description prompt |
| ABAP coding | Generates production-quality ABAP with correct SAP FM names and table references |
| Code review | Reviews generated code for performance anti-patterns and missing error handling |
| Unit tests | Generates full `CL_ABAP_UNIT_ASSERT`-based test classes |
| Python pipeline | Generates complete, runnable scripts with retry and delta logic |
| Documentation | Generates runbooks, ADRs, and transport docs concurrently with code |
| QA evidence | Generates test scripts and result tables from unit test output |
| Iteration | Applies targeted diffs from reviewer feedback in seconds |

---

### Risk & Dependency Register

| Risk | Mitigation with Bob |
|------|---------------------|
| SAP FM interfaces differ between R/3 releases | Bob adjusts code to the target release on request |
| 40,000 exits causes batch timeout | Bob generates package-size pagination and resumable job logic |
| Vector DB schema changes mid-project | Bob regenerates the ingestion script from updated schema in minutes |
| New object types identified late | Bob adds a new extraction module in one session without rework |
| Staff turnover mid-project | Bob-generated documentation is comprehensive enough to onboard a replacement same day |

---

## 6. Priority Scoring Algorithm

Priority scores allow future RAG queries to weight more important metadata sources higher.

```abap
METHODS calculate_priority
  IMPORTING
    is_custom      TYPE abap_bool
    is_modified    TYPE abap_bool
    object_type    TYPE trobjtype
    usage_count    TYPE i
    last_change    TYPE datum
  RETURNING
    VALUE(rv_prio) TYPE i.

  DATA(lv_prio) = 50.  " Base score

  " Boost for custom objects
  IF is_custom = abap_true.
    lv_prio = lv_prio + 30.
  ENDIF.

  " Higher boost for modifications (higher risk/relevance)
  IF is_modified = abap_true.
    lv_prio = lv_prio + 40.
  ENDIF.

  " Type-based scoring
  CASE object_type.
    WHEN 'FUNC' OR 'FUGR' OR 'METH'.
      lv_prio = lv_prio + 20.  " Executable code
    WHEN 'ENHS' OR 'SMOD' OR 'BADI'.
      lv_prio = lv_prio + 25.  " Enhancement points — highest priority
    WHEN 'TABL' OR 'VIEW'.
      lv_prio = lv_prio + 15.  " Data structures
    WHEN OTHERS.
      lv_prio = lv_prio + 5.
  ENDCASE.

  " Usage frequency bonus
  lv_prio = lv_prio + ( usage_count / 100 ).

  " Recency bonus (changed within 90 days)
  DATA(lv_days_old) = cl_abap_tstmp=>subtract(
    tstmp1 = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
    tstmp2 = |{ last_change }000000| ).

  IF lv_days_old < 90.
    lv_prio = lv_prio + 10.
  ENDIF.

  rv_prio = lv_prio.

ENDMETHOD.
```

**Default Priority Bands:**

| Layer | Object Type | Base Priority |
|-------|-------------|---------------|
| CUSTOM | SMOD / BAdi impl | 95+ |
| CUSTOM | Enhancement (ENHS) | 90–95 |
| CUSTOM | Function Module | 85–90 |
| MODIFIED | Any SAP object | 90+ |
| SAP_BASIS | BAPI / RFC | 80–85 |
| SAP_BASIS | Core Table | 75–80 |
| SAP_BASIS | Data Element / Domain | 60–70 |

---

## 7. Output Format (JSONL)

One JSON object per line for streaming-friendly ingestion:

```jsonl
{"chunk_id":"uuid1","type":"EXIT","name":"EXIT_SAPMM03M_001","text":"User Exit EXIT_SAPMM03M_001...","metadata":{"priority":95,"layer":"CUSTOM","is_custom":true,...}}
{"chunk_id":"uuid2","type":"FUNC","name":"Z_CUSTOM_VALIDATE","text":"Custom function Z_CUSTOM_VALIDATE...","metadata":{"priority":90,"layer":"CUSTOM","is_custom":true,...}}
{"chunk_id":"uuid3","type":"TABL","name":"MARA","text":"Table MARA Material Master...","metadata":{"priority":85,"layer":"SAP_BASIS","is_custom":false,...}}
```

---

## 8. Vector Database Schema

**Recommended Database: OpenSearch** — deployed on IBM Cloud or as a managed service via IBM Cloud Databases. OpenSearch natively supports hybrid search (dense vector KNN + BM25 keyword), which is ideal for SAP metadata where both semantic similarity (RAG) and exact token matching (object names, transaction codes) are required.

#### OpenSearch Index Mapping

```json
{
  "settings": {
    "index": {
      "knn": true,
      "knn.algo_param.ef_search": 100
    }
  },
  "mappings": {
    "properties": {
      "chunk_id":        { "type": "keyword" },
      "embedding_text":  { "type": "text", "analyzer": "standard" },
      "embedding_vector": {
        "type": "knn_vector",
        "dimension": 768,
        "method": {
          "name": "hnsw",
          "space_type": "cosinesimil",
          "engine": "nmslib"
        }
      },
      "source_system":   { "type": "keyword" },
      "object_name":     { "type": "keyword" },
      "object_type":     { "type": "keyword" },
      "package":         { "type": "keyword" },
      "layer":           { "type": "keyword" },
      "priority":        { "type": "integer" },
      "is_custom":       { "type": "boolean" },
      "is_modified":     { "type": "boolean" },
      "extraction_date": { "type": "date" },
      "parent_objects":  { "type": "keyword" },
      "used_by_count":   { "type": "integer" }
    }
  }
}
```

---

## 9. RAG Query Filters (OpenSearch Hybrid Search)

OpenSearch hybrid search combines BM25 keyword scoring with KNN vector similarity in a single query. This is especially powerful for SAP metadata, where a user might ask a natural-language question but also mention exact object names like `MARA` or `EXIT_SAPMM03M_001`.

#### Hybrid Query — Custom Layer, High Priority

```json
{
  "size": 10,
  "query": {
    "bool": {
      "must": [
        {
          "knn": {
            "embedding_vector": {
              "vector": "<query_embedding>",
              "k": 10
            }
          }
        }
      ],
      "filter": [
        { "term":  { "layer": "CUSTOM" } },
        { "range": { "priority": { "gte": 90 } } }
      ]
    }
  }
}
```

#### Hybrid Query — Specific Packages

```json
{
  "query": {
    "bool": {
      "must": [
        { "knn": { "embedding_vector": { "vector": "<query_embedding>", "k": 10 } } }
      ],
      "filter": [
        { "terms": { "package": ["ZMATERIAL", "ZSALES"] } }
      ]
    }
  }
}
```

#### Hybrid Query — Modified SAP Objects Only (Highest Risk)

```json
{
  "query": {
    "bool": {
      "must": [
        { "knn": { "embedding_vector": { "vector": "<query_embedding>", "k": 10 } } },
        { "match": { "embedding_text": "<natural language query>" } }
      ],
      "filter": [
        { "term": { "is_modified": true } }
      ]
    }
  }
}
```

#### Python Client (opensearch-py)

```python
from opensearchpy import OpenSearch

client = OpenSearch(hosts=[{"host": "your-opensearch-host", "port": 443}], use_ssl=True)

response = client.search(
    index="sap-metadata",
    body={
        "size": 10,
        "query": {
            "bool": {
                "must": [{"knn": {"embedding_vector": {"vector": query_embedding, "k": 10}}}],
                "filter": [
                    {"term":  {"layer": "CUSTOM"}},
                    {"range": {"priority": {"gte": 90}}}
                ]
            }
        },
        "_source": ["chunk_id", "object_name", "object_type", "layer",
                    "priority", "parent_objects", "embedding_text"]
    }
)
```

---

## 10. Recommended Technology Stack

### SAP Side

| Component | Purpose |
|-----------|---------|
| ABAP Report (7.40+) | Metadata extraction, JSON serialisation |
| Background Job (SM36/SM37) | Scheduled weekly/monthly execution |
| Application Server filesystem | Staging area for JSONL output |
| SFTP / SAP PI/PO | Secure file transfer to external pipeline |

### Processing Layer

| Component | Purpose |
|-----------|---------|
| Python 3.11+ | Orchestration and embedding pipeline |
| `ibm-watsonx-ai` | IBM Slate embedding calls via watsonx.ai API |
| `opensearch-py` | OpenSearch index management and hybrid queries |
| `langchain-ibm` | RAG orchestration with watsonx.ai LLM integration |
| `pandas` | Data transformation and deduplication |

### Vector Database: OpenSearch on IBM Cloud

| Deployment Option | Notes |
|-------------------|-------|
| **IBM Cloud Databases for OpenSearch** | Fully managed, IBM Cloud-native, recommended for production |
| **OpenSearch on IBM Cloud Pak for Data** | On-premises or private cloud, suits air-gapped SAP estates |
| **Self-managed OpenSearch on IKS/ROKS** | IBM Kubernetes / Red Hat OpenShift — maximum control |

OpenSearch is the strategic choice because it:
- Natively combines **KNN vector search** and **BM25 keyword search** in a single hybrid query
- Is fully open-source (Apache 2.0) — no vendor lock-in
- Is deployable on IBM Cloud, on-premises, or in a private cloud alongside an air-gapped SAP system
- Supports **index-level access control** aligned to IBM IAM

### Embedding Models: IBM Slate

IBM Slate models are available via **IBM watsonx.ai** on IBM Cloud and IBM Cloud Pak for Data. They are the preferred embedding models for IBM-delivered solutions.

| Model | Dimensions | Use Case |
|-------|-----------|----------|
| `ibm/slate-125m-english-rtrvr` | 768 | Primary recommendation — fast, efficient, English SAP metadata |
| `ibm/slate-30m-english-rtrvr` | 384 | High-throughput / cost-optimised bulk embedding of large estates |

**Why IBM Slate for this use case:**
- Optimised for retrieval tasks (`rtrvr` = retriever), directly aligned with RAG workloads
- Available via the [watsonx.ai embeddings API](https://cloud.ibm.com/apidocs/watsonx-ai) — no third-party dependency
- Deployable on IBM Cloud Pak for Data for on-premises / data-sovereign requirements
- 768-dimension output fits OpenSearch KNN indexes efficiently

#### Calling IBM Slate via watsonx.ai

```python
import requests

def get_slate_embedding(text: str, api_key: str, project_id: str) -> list[float]:
    url = "https://us-south.ml.cloud.ibm.com/ml/v1/text/embeddings?version=2024-03-19"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "model_id": "ibm/slate-125m-english-rtrvr",
        "project_id": project_id,
        "inputs": [text]
    }
    response = requests.post(url, headers=headers, json=payload)
    return response.json()["results"][0]["embedding"]
```

---

## 11. Incremental Extraction (Delta Detection)

Avoid re-embedding unchanged objects by hashing the content:

```python
import hashlib, json

def compute_chunk_hash(chunk: dict) -> str:
    """Stable hash of content — excludes extraction_ts."""
    stable = {k: v for k, v in chunk.items() if k != "extraction_ts"}
    return hashlib.sha256(
        json.dumps(stable, sort_keys=True).encode()
    ).hexdigest()

def should_upsert(new_chunk: dict, existing_hash: str) -> bool:
    return compute_chunk_hash(new_chunk) != existing_hash
```

On the ABAP side, maintain a control table:

```abap
TABLES: ztab_extract_ctrl.
" Fields: object_name, object_type, last_hash, last_extract_ts, status
```

Only re-extract and re-embed objects whose source has changed since the last run.

---

## Next Steps

1. **Generate a complete ABAP extractor** for one object type (e.g., function modules) as a working prototype
2. **Create the Python pipeline** for embedding generation and vector DB ingestion
3. **Build a sample RAG query interface** showing how to query SAP metadata
4. **Design the delta extraction logic** with full hash comparison and control table

---

*Architecture designed for SAP R/3 estates with 40,000+ exits. Suitable for weekly or monthly batch extraction with full RAG lineage support.*
