# JEDx Technical Documentation

## Overview

This site is made up of three main sections

- JEDx Transport: CAR and Collector Service Software. This document contains an introduction to the project as well as requirements that were used to develop the Phase II software. Not all requirements were implemented.

- Orchestration: CAR and Collector Service Software document. This document lays out the AWS architecture that was implemented in Phase II. Since this document reflects what was actually implemented in Phase II, there may be some variances compared to Part A.

- Data Model: Information related to the JEDx JASON objects. 

## JEDx System Overview

### CAR Application 

- Currently in pilot state: manual upload of files into the "input bucket"

- object/files are automatically fed into pipeline, schemas are validated, objects are put into send bucket or into an error bucket.

- Nothing is done with the Error objects for now (pilot state).

- Send bucket items are not sent immediately at this time. Sending will be done by the UI, by automation in the future.

Before objects are sent:

- Read only view of Organizations, Workers, reports

- View of logs in several ways.

- Job objects missing SOC codes (or do not have the state mandated code) go through the lookup and edit process in the UI. (The objects being edited are in the Send Bucket.)

### Receiver (collector) Application

- objects are received and logged. No manual editing. Items are marked received.

- UI allows multiple views of logs.

- after processing (logging) objects are dropped in the "output bucket" for a third party to pick up.

