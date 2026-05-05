# JEDx Phase II Technical Documentation

## Overview

Documents in this .zip file comprise the technical report for the Phase II JEDx Pilot. It is made up of:

- Part A: The JEDx Requirements - CAR and Collector Service Software. This document contains an introduction to the project as well as requirements that were used to develop the Phase II software. Not all requirements were implemented.

- Part B: The JEDx AWS Architecture – CAR and Collector Service Software document. This document lays out the AWS architecture that was implemented in Phase II. Since this document reflects what was actually implemented in Phase II, there may be some variances compared to Part A.

- Part C: A folder that contains information related to implementing the Phase II software using AWS SAM (serverless application model) configuration files. Two distinct applications are installed using the AWS CLI (command line interface) – the provider software and the collector software (see Part A for detail). Each application has a quick start, a walk through and an annotated SAM Template in the Part C folder.

## Application Process Flow

These technical documents and files provide detail concerning the design and development of the Phase II software. From a user perspective, here is what it does:

### CAR Application 

- manual upload of files into the "input bucket"

- object/files are automatically fed into pipeline, schemas are validated, objects are put into send bucket or into an error bucket.

<!-- -->

- Nothing is done with the Error objects for now.

- Send bucket items are not sent immediately at this time. Sending will be done by the UI, by automation in the future.

Before objects are sent:

- Read only view of Organizations, Workers, reports

- View of logs in several ways.

- Job objects missing SOC codes (or do not have the state mandated code) go through the lookup and edit process in the UI. (The objects being edited are in the Send Bucket.)

### Receiver (collector) Application

- objects are received and logged. No editing. Items are marked received.

- UI allows multiple views of logs.

- after processing (logging) objects are dropped in the "output bucket" for BrightHive to pick up.

## Github files

All software and code documentation is stored in Github at:

- <https://github.com/QIPDataHub/JEDx> - Schemas and Data Dictionary

- <https://github.com/QIPDataHub/jedx-car-collector-service> - Both the CAR Service app (provider) and the Collector Service app.

- <https://github.com/QIPDataHub/webui_shared_artifacts> - The CAR Service web UI and the Collector Service web UI compiled code.

- <https://github.com/QIPDataHub/jedx-car-receiver-webui> - The web UI source code for both the CAR Service and the Collector Service.
