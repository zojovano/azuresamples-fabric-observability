## Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog principles (simplified) and uses semantic version pre-1.0 expectations (APIs may change at any time).

### 0.9 - 2025-09-16
Initial public preview of Fabric-based OpenTelemetry gateway pattern.

Highlights:
- Added upstream tutorial disclaimer clarifying extension of Microsoft Learn OpenTelemetry connector scenario
- Implemented custom OTEL Collector gateway (Event Hub + OTLP ingestion → Fabric export) documentation
- Added Azure Container Registry build/push guidance for custom collector image
- Introduced Git synchronization pattern for Fabric artifacts (`deploy/fabric-artifacts/`)
- Added table definition KQL files (`otel-logs.kql`, `otel-metrics.kql`, `otel-traces.kql`)
- Renamed collector folder to `app/otel-collector` (from legacy naming) for clarity
- Refactored .NET sample worker path to `app/OTELdotNetClient` and removed solution-centric build approach
- Removed obsolete solution file and aligned docs to project-based build workflow (pending minor doc enhancement)
- Added documentation for Azure Event Hub diagnostic ingestion pattern
- Unified README structure with architectural diagrams and gateway pattern explanation

Known follow-ups (not blocking 0.9):
- Add explicit no-solution build workflow section to docs/README.md and root README
- Expand automation around Fabric Git sync optional script usage
- Add lightweight test/run script for .NET sample if needed

---

Earlier internal iterations are not tagged; 0.9 represents the first consolidated snapshot.