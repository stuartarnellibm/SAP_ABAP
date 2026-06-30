---
name: create-unilever-cdd
description: >-
  Create a conceptual design document for an SAP requirement, built to Unilever
  standards and conntextualised by Unilever cureent configuration
---

Create a conceptual design document.  Along the way, you should be celar about what your next steps are, and ask any clarification questions you may need.

1.   Understand the requirement.  This will be provided to you, but you shuld ask any clarification questions you need

2.   Understand how this relates to the SAP components that are active - specifically O2C and Warehousing.  You can use your base 
SAP knowledge for this.  If an SAP MCP server, or further SAP documentatin is made available, you should use it

3.   Understand the current Unilever SAP context, including current customisation, configuration, standards, systems, internal and external integration, and code

4.   Build a design specificaton, taking all of the above into account.  The design specification outline reference is contained in the mode for a Unilever SAP Delivery Manager

5.  Re-review the specification you have produced against the Unilever context.  Ensure that context is considered and applied, and any standards are adhered to.

You should use the SA_SAP_Repo_99901A agent to identify the Unilever context and standards that should be considered and adhered to.


The format of the CDD document is as follows.

SPECIFICATION DOCUMENT STRUCTURE:
Every specification you create MUST include these sections in order:

Overview

Business context and problem statement
High-level solution approach
Stakeholders and their roles
Scope

In-scope items (what will be delivered)
Out-of-scope items (what will NOT be delivered)
Boundaries and interfaces
Functional Description

Detailed business process description
User stories or use cases
Business rules and logic
Data flow and transformations
Functional Requirements

Numbered list of specific functional requirements (FR-001, FR-002, etc.)
Each requirement must be testable and measurable
Priority (Must Have, Should Have, Could Have)
Dependencies/Constraints/Limitations

Technical dependencies (systems, interfaces, data)
Business constraints (timing, resources, budget)
Known limitations of the solution
Assumptions

Key assumptions made during specification
Conditions that must be true for success
Risks if assumptions prove false
Security Requirements

Authorization requirements (roles, profiles)
Data protection and privacy considerations
Audit and compliance requirements
Test Requirements

Unit test scenarios
Integration test scenarios
User acceptance test criteria
Performance test requirements
Technical Logic for Development Team

Detailed technical approach
SAP objects to be created/modified (programs, function modules, tables, etc.)
Data structures and field mappings
Error handling approach
Case Configuration Logic

Configuration settings required
Customizing tables and values
IMG path references
Flow Diagram

Process flow diagram (describe in text for .docx generation)
System interaction diagram
Data flow diagram
Assessment of Impact on and of Existing Customization

Impact on existing Z-objects and custom code
Impact on standard SAP functionality
Required changes to existing customizations
Regression testing requirements


QUALITY STANDARDS:

All requirements must be specific, measurable, and testable
Technical details must be accurate and implementable
Impact analysis must be thorough and realistic
Document must be ready for handoff to development team
Use proper SAP terminology and object naming conventions
