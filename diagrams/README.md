# Diagrams

Source files are in [draw.io](https://app.diagrams.net/) format (`.drawio`).

## How to view / edit

- **Browser:** open https://app.diagrams.net/, then **File → Open from Device** → pick the `.drawio` file
- **VS Code:** install the [Draw.io Integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) extension; open the file natively
- **Desktop:** download the [draw.io desktop app](https://github.com/jgraph/drawio-desktop/releases)

## How to export to PNG / SVG (for embedding in README)

In draw.io: **File → Export as → PNG** (or SVG). Save with the same base name into `diagrams/`:

```
diagrams/architecture.drawio  ← editable source
diagrams/architecture.png     ← exported (referenced from README.md)
diagrams/architecture.svg     ← exported (optional, vector)
```

For batch export from CLI (with the desktop app installed):

```bash
drawio --export --format png   --output architecture.png   architecture.drawio
drawio --export --format svg   --output architecture.svg   architecture.drawio
```

## Files

| File                   | Purpose                                                       |
|------------------------|---------------------------------------------------------------|
| `architecture.drawio`  | Top-level topology: spokes, TGW, inspection VPC, NFW, egress  |
| `traffic-flow.drawio`  | (optional) Detailed forward / return path with route tables   |
| `threat-model.drawio`  | (optional) STRIDE diagram on the egress path                  |

## Conventions

- Use the **AWS 2024 (mxgraph.aws4)** shape library for consistency
- Color the **inspection VPC** in red (`#C7131F`) to highlight the trust boundary
- Solid arrows = data plane; dashed arrows = control plane / logging
- Annotate non-obvious design decisions (e.g., "Firewall before NAT") inline
