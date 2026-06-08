# Data Model

JSON Schema definitions for the JEDx data model. Each file is downloadable.

## `code-sets.json`

**Central Code Sets**

[Download `code-sets.json`](assets/data-model/code-sets.json){ .md-button }

## `job_schema.jschema`

**Job Schema**

An ongoing role or set of responsibilities at an organization.

[Download `job_schema.jschema`](assets/data-model/job_schema.jschema){ .md-button }

## `organization_schema.jschema`

**Organization Schema**

A legal Organization

[Download `organization_schema.jschema`](assets/data-model/organization_schema.jschema){ .md-button }

## `worker_compensation_report.jschema`

**Worker Compensation Report Schema**

Reports compensation to workers

[Download `worker_compensation_report.jschema`](assets/data-model/worker_compensation_report.jschema){ .md-button }

## `worker_paid_hours_report.jschema`

**Worker Paid Hours ReportSchema**

Reports hours paid to a worker.

[Download `worker_paid_hours_report.jschema`](assets/data-model/worker_paid_hours_report.jschema){ .md-button }

## `worker_schema.jschema`

**Worker Schema**

A person entity that works for an organization.

[Download `worker_schema.jschema`](assets/data-model/worker_schema.jschema){ .md-button }

## Sample Data

[Download all sample data (ZIP)](assets/zips/sample-data.zip){ .md-button .md-button--primary }

> **Note**  
> - These are artifacts for **JEDx Phase II Pilot**  
> - Not meant for production  

---

This folder contains **synthetic sample data files** used in the Stage 2 demonstration of the JEDx Phase II Pilot. The files were created to simulate how data flow through the system when using the **JEDx CAR service** to send files and the **JEDx Collector service** to receive them.  

The data here are entirely synthetic and intended solely for **demonstration purposes**. These data files allow project participants to test workflows, validate schema handling, and illustrate the sender/receiver interaction without using real-world or sensitive data.  

Files are organized into three subfolders to reflect different data sets used during the demo. Each subfolder corresponds to a scenario that was exercised to showcase the end-to-end data pipeline.

### Contents

- **plumbingMultiState/** — 31 files
- **restaurantSouthCarolina/** — 37 files
- **stateAgencyArkansas/** — 34 files
