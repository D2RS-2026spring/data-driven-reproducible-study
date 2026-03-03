# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Quarto Book** for a university course on "Data Driven Reproducible Study" (数据驱动的可重复性研究). It teaches reproducible research practices using R, Python, Quarto, and modern AI/ML tools.

The book is bilingual (Chinese primary, English secondary) and covers:
- Environment setup (R, Python, Conda, Git)
- Data analysis (grouped data, transcriptomics, microbiome)
- AI/ML (neural networks from scratch, computer vision with PyTorch)
- LLM API integration (OpenAI, DeepSeek, Hugging Face)
- Collaboration (GitHub, R package development)

## Build Commands

### Render the Book

```bash
# Render entire book (HTML output)
quarto render

# Render to PDF (requires TinyTeX)
quarto render --to pdf

# Render specific file
quarto render grouped-data-analysis.qmd
```

### Clean Build Artifacts

```bash
make clean          # Remove _book/ directory
rm -rf _freeze      # Clear execution cache (if code chunks misbehave)
```

### Deploy

```bash
make deploy         # Run deployment script (_deploy.sh)
make book           # Render book via Makefile
```

### Update Dependencies

```bash
# R packages - uses renv
Rscript -e "renv::snapshot()"     # Save current packages to renv.lock
Rscript -e "renv::restore()"      # Restore packages from renv.lock

# Python packages - uses Conda
conda env update -f environment.yml
conda activate data-driven-reproducible-study

# Update package citations
Rscript _packages.R
```

## Development Environment

### Required Tools

1. **R** (4.3+) with renv for package management
2. **Python** (3.10) with Conda environment `data-driven-reproducible-study`
3. **Quarto** (latest version)
4. **Git** with LFS support

### R Configuration (.Rprofile)

- Uses USTC mirrors for CRAN and Bioconductor
- pak enabled for faster package installation
- showtext for Chinese font rendering
- reticulate configured for Python interoperability

### Python Configuration

- Conda environment defined in `environment.yml`
- Key packages: PyTorch, transformers, openai, jupyter
- GPU support optional but recommended for ML chapters

## Project Structure

```
├── _quarto.yml              # Book configuration and chapter order
├── _freeze/                 # Execution cache for code chunks
├── _book/                   # Rendered HTML output (gitignored)
├── book-output/             # Git worktree for gh-pages deployment
├── renv/                    # R package library (managed by renv)
│   ├── activate.R
│   └── lockfile (renv.lock)
├── environment.yml          # Conda environment specification
├── custom.css               # Custom styles for HTML output
├── *.qmd                    # Main content files (Quarto markdown)
├── slides/                  # Lecture slides (*.qmd, *.html, *.pdf)
├── data/                    # Datasets used in examples
├── images/                  # Static images and generated figures
├── deg/                     # Differential expression analysis submodule
├── bacteria-ID/             # Raman spectroscopy classification submodule
├── SegVeg/                  # Computer vision segmentation submodule
└── .github/workflows/       # CI/CD for automated deployment
```

## Quarto Configuration

### Key Settings (_quarto.yml)

- **Engine**: Jupyter (for Python) and Knitr (for R) - specified per-chunk
- **Freeze**: `auto` - only re-execute changed chunks
- **Bibliography**: `references.bib` and `packages.bib`
- **Formats**: HTML (cosmo theme) and PDF (ctexbook for Chinese)

### Code Chunk Options

Common options used across chapters:
```yaml
warning: false          # Suppress warnings
message: false          # Suppress messages
fig-width: 7            # Figure width in inches
fig-asp: 0.618          # Golden ratio aspect
fig-align: center       # Center figures
```

### Multi-language Support

- **R chunks**: Use `{r}` with tidyverse, showtext for Chinese
- **Python chunks**: Use `{python}` with matplotlib, torch
- **Mermaid diagrams**: Use `{mermaid}` for flowcharts

## Subprojects

### deg/

Differential gene expression analysis example using R.
- Uses DESeq2/edgeR workflow
- Has its own renv and git history

### bacteria-ID/

PyTorch-based ResNet for pathogen identification from Raman spectra.
- Notebooks for fine-tuning and prediction
- Pretrained model files (.ckpt) tracked with Git LFS

### SegVeg/

Computer vision project for vegetation segmentation.
- Dockerfile for containerized training
- Jenkins pipeline configuration
- Python package structure with setup.py

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/deploy.yml`):

1. Runs on macOS (for Apple Silicon compatibility)
2. Sets up Conda environment from `environment.yml`
3. Restores R packages via renv
4. Installs Quarto with TinyTeX
5. Renders book to HTML
6. Deploys to gh-pages branch

Manual trigger only (`workflow_dispatch`) - no auto-deploy on push.

## Common Development Tasks

### Add a New Chapter

1. Create `new-chapter.qmd` in root
2. Add to `_quarto.yml` in appropriate part
3. Run `quarto render new-chapter.qmd` to test

### Update Bibliography

1. Add BibTeX entries to `references.bib`
2. Cite with `[@citation-key]` in text
3. Quarto automatically generates reference list

### Handle Large Files

- Use Git LFS for files >100MB (model weights, large datasets)
- Configure in `.gitattributes` and `.lfsconfig`
- OSS bucket used for backup: `oss://hzau-micro-gaoch/` (see .lfsconfig)

### Chinese Font Issues

- showtext package handles font rendering
- Uses system fonts via fontconfig
- If fonts fail in PDF, ensure ctex package is installed

## License

CC BY-NC-SA 4.0 - Creative Commons Attribution-NonCommercial-ShareAlike
