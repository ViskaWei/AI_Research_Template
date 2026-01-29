#!/bin/bash
#==============================================================================
# AI Research Template - Report Compiler
# Author: Viska Wei
# Usage: ./compile_report.sh <topic> <phase>
#==============================================================================

set -e

TOPIC="${1:-default}"
PHASE="${2:-1}"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname $(dirname $(dirname $(realpath $0))))}"
REPORTS_DIR="${PROJECT_ROOT}/reports"
SOURCE_DIR="${REPORTS_DIR}/${TOPIC}/phase${PHASE}"
OUTPUT_DIR="${REPORTS_DIR}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              📝 AI Research Report Compiler                    ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Topic: ${TOPIC}"
echo "║  Phase: ${PHASE}"
echo "║  Source: ${SOURCE_DIR}"
echo "║  Output: ${OUTPUT_DIR}"
echo "╚════════════════════════════════════════════════════════════════╝"

# Check if source exists
if [ ! -d "${SOURCE_DIR}" ]; then
    echo "❌ Error: Source directory not found: ${SOURCE_DIR}"
    echo "   Creating directory structure..."
    mkdir -p "${SOURCE_DIR}/figures"
    echo "   Please add your .tex file to ${SOURCE_DIR}/"
    exit 1
fi

# Find the main .tex file
TEX_FILE=$(find "${SOURCE_DIR}" -maxdepth 1 -name "*.tex" | head -1)

if [ -z "${TEX_FILE}" ]; then
    echo "❌ Error: No .tex file found in ${SOURCE_DIR}"
    exit 1
fi

TEX_BASENAME=$(basename "${TEX_FILE}" .tex)
echo "📄 Compiling: ${TEX_FILE}"

# Change to source directory for compilation
cd "${SOURCE_DIR}"

# Compile LaTeX (run twice for references)
echo "🔄 Running pdflatex (pass 1)..."
pdflatex -interaction=nonstopmode -halt-on-error "${TEX_BASENAME}.tex" > /dev/null 2>&1 || {
    echo "⚠️  First pass had issues, checking..."
    pdflatex -interaction=nonstopmode "${TEX_BASENAME}.tex" 2>&1 | tail -20
}

# Check for bibliography
if [ -f "${TEX_BASENAME}.bib" ]; then
    echo "📚 Running bibtex..."
    bibtex "${TEX_BASENAME}" > /dev/null 2>&1 || true
fi

echo "🔄 Running pdflatex (pass 2)..."
pdflatex -interaction=nonstopmode -halt-on-error "${TEX_BASENAME}.tex" > /dev/null 2>&1 || true

echo "🔄 Running pdflatex (pass 3 - final)..."
pdflatex -interaction=nonstopmode "${TEX_BASENAME}.tex" > /dev/null 2>&1 || true

# Check if PDF was created
if [ -f "${TEX_BASENAME}.pdf" ]; then
    # Copy to output directory with standardized name
    OUTPUT_NAME="phase${PHASE}_${TOPIC}_report.pdf"
    cp "${TEX_BASENAME}.pdf" "${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "✅ Success! PDF saved to: ${OUTPUT_DIR}/${OUTPUT_NAME}"
    
    # Also keep a copy with original name
    cp "${TEX_BASENAME}.pdf" "${OUTPUT_DIR}/${TEX_BASENAME}.pdf"
    
    # Clean up auxiliary files
    echo "🧹 Cleaning up auxiliary files..."
    rm -f *.aux *.log *.out *.toc *.bbl *.blg *.lot *.lof 2>/dev/null || true
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  📊 Report compiled successfully!"
    echo "  📁 Location: ${OUTPUT_DIR}/${OUTPUT_NAME}"
    echo "════════════════════════════════════════════════════════════════"
else
    echo "❌ Error: PDF compilation failed"
    echo "   Check the log file for details:"
    cat "${TEX_BASENAME}.log" | tail -50
    exit 1
fi
