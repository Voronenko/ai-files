# 2. Implement PlantUML Diagramming Mode

Date: 2025-07-06

## Status

Accepted


## Context
We frequently need to create and maintain architecture diagrams in our documentation. PlantUML provides a text-based diagramming solution that:
- Can be version controlled
- Is easy to modify
- Supports various diagram types (sequence, class, component, etc.)
- Integrates well with Markdown documentation

Currently, we have to create these diagrams externally and import images, which makes maintenance difficult.

## Decision
Implement a dedicated PlantUML mode with:
1. A YAML mode definition in `modes/plantuml.yml`
2. Specialized capabilities for:
   - Generating diagrams from text
   - Previewing diagrams
   - Converting between formats
3. Integration with our documentation pipeline

## Consequences
- Positive:
  - Unified diagram creation workflow
  - Better documentation maintainability
  - Text-based diagrams can be diffed/merged
- Negative:
  - Additional dependency on PlantUML
  - Learning curve for team members
  - Requires Java runtime for PlantUML
