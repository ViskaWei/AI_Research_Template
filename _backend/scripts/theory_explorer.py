#!/usr/bin/env python3
"""
AI Research Template - Theory Explorer
Author: Viska Wei

Automated theoretical analysis for research projects:
1. Search for relevant theory papers
2. Extract key theoretical results
3. Compute theoretical bounds (CRLB/Fisher)
4. Generate theory.tex file

Usage:
    python theory_explorer.py "learning from unlabeled data" --topic ips_unlabeled
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

# Import paper search
sys.path.insert(0, str(Path(__file__).parent))
from search_papers import search_arxiv, search_perplexity, generate_bibtex


# ============================================================================
# Theory Analysis Prompts
# ============================================================================

THEORY_ANALYSIS_PROMPT = """You are a theoretical machine learning researcher. Analyze the following research problem and provide a comprehensive theoretical framework.

Research Problem: {problem}

Provide analysis in the following structure:

1. **Problem Formulation**
   - Mathematical model
   - Key assumptions (A1, A2, A3...)
   - Loss function definition

2. **Identifiability Analysis**
   - Under what conditions is the solution unique?
   - What are the symmetries/degeneracies?
   - Coercivity conditions

3. **Convergence Analysis**
   - Consistency: Does estimator converge to truth?
   - Rate: How fast? (parametric n^{-1/2} or nonparametric n^{-s/(2s+d)})
   - Dependencies: On dimension d, smoothness s, sample size n

4. **Lower Bounds**
   - Information-theoretic limits (Fano, Le Cam)
   - Fisher information / CRLB
   - Minimax optimality

5. **Key References**
   - Foundational papers
   - Recent advances
   - Related problems

Be precise with mathematical notation. Use LaTeX formatting."""


# ============================================================================
# Generate Theory Document
# ============================================================================

def generate_theory_tex(problem: str, analysis: str, papers: list, output_dir: Path) -> Path:
    """Generate a complete theory.tex document."""
    
    # Template
    template = r"""%% ============================================================================
%% Theoretical Analysis - Auto-generated
%% Author: Viska Wei
%% Generated: {date}
%% ============================================================================

\documentclass[11pt]{{article}}
\usepackage{{amsmath,amssymb,amsthm}}
\usepackage[margin=1in]{{geometry}}
\usepackage{{hyperref}}
\usepackage{{tcolorbox}}

\newtheorem{{theorem}}{{Theorem}}[section]
\newtheorem{{proposition}}[theorem]{{Proposition}}
\newtheorem{{lemma}}[theorem]{{Lemma}}
\newtheorem{{definition}}[theorem]{{Definition}}
\newtheorem{{remark}}[theorem]{{Remark}}
\newtheorem{{assumption}}{{Assumption}}

\title{{\textbf{{Theoretical Analysis}}\\[0.5em]
\large {problem}}}
\author{{Viska Wei}}
\date{{\today}}

\begin{{document}}
\maketitle

\begin{{abstract}}
This document presents a comprehensive theoretical analysis for the research problem:
\emph{{{problem}}}.
We establish identifiability conditions, convergence rates, and information-theoretic lower bounds.
\end{{abstract}}

\tableofcontents
\newpage

%% ============================================================================
%% AI-Generated Analysis
%% ============================================================================

{analysis}

%% ============================================================================
%% Related Work
%% ============================================================================

\section{{Related Work}}

The following papers are relevant to this theoretical analysis:

\begin{{enumerate}}
{paper_list}
\end{{enumerate}}

\bibliographystyle{{plain}}
\bibliography{{related_papers}}

\end{{document}}
"""
    
    # Format paper list
    paper_list = ""
    for p in papers[:10]:
        title = p.get('title', 'Unknown').replace('_', r'\_').replace('&', r'\&')
        authors = ', '.join(p.get('authors', ['Unknown'])[:2])
        url = p.get('url', '')
        paper_list += f"    \\item \\textbf{{{title}}} by {authors}. \\url{{{url}}}\n"
    
    # Generate content
    content = template.format(
        date=datetime.now().strftime("%Y-%m-%d"),
        problem=problem.replace('_', r'\_'),
        analysis=analysis,
        paper_list=paper_list
    )
    
    # Write files
    output_dir.mkdir(parents=True, exist_ok=True)
    
    tex_path = output_dir / "theoretical_analysis.tex"
    with open(tex_path, 'w') as f:
        f.write(content)
    
    # Write BibTeX
    bib_path = output_dir / "related_papers.bib"
    with open(bib_path, 'w') as f:
        f.write(generate_bibtex(papers))
    
    return tex_path


# ============================================================================
# Theoretical Bounds Calculator
# ============================================================================

def compute_fisher_info_template():
    """Return template for Fisher information computation."""
    return r"""
\section{Fisher Information and CRLB}

\subsection{Fisher Information Matrix}

For a parametric model $p(X; \theta)$, the Fisher information is:
\begin{equation}
I(\theta) = \mathbb{E}\left[\nabla_\theta \log p(X; \theta) \nabla_\theta \log p(X; \theta)^\top\right]
\end{equation}

\subsection{Cramér-Rao Lower Bound}

For any unbiased estimator $\hat{\theta}$:
\begin{equation}
\mathrm{Var}(\hat{\theta}) \geq I(\theta)^{-1}
\end{equation}

\subsection{Practical Computation}

For the specific problem at hand, the Fisher information can be computed as:

\begin{tcolorbox}[colback=yellow!5!white,colframe=yellow!75!black,title=TODO: Problem-Specific Fisher]
Replace with actual Fisher information computation for your problem:
\begin{itemize}
    \item Model: $p(X; \theta) = ...$
    \item Score: $\nabla_\theta \log p = ...$
    \item Fisher: $I(\theta) = ...$
    \item CRLB: $\mathrm{Var}(\hat{\theta}) \geq ...$
\end{itemize}
\end{tcolorbox}
"""


# ============================================================================
# Main
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='Theory Explorer')
    parser.add_argument('problem', help='Research problem description')
    parser.add_argument('--topic', '-t', default='default', help='Topic name for output directory')
    parser.add_argument('--output', '-o', help='Output directory (default: experiments/<topic>/theory/)')
    parser.add_argument('--search-only', action='store_true', help='Only search papers, no theory generation')
    
    args = parser.parse_args()
    
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║              📚 AI Research Theory Explorer                    ║")
    print("╠════════════════════════════════════════════════════════════════╣")
    print(f"║  Problem: {args.problem[:50]}...")
    print(f"║  Topic: {args.topic}")
    print("╚════════════════════════════════════════════════════════════════╝\n")
    
    # 1. Search for relevant papers
    print("🔍 Step 1: Searching for relevant theory papers...")
    
    # Search arXiv (math/stat categories for theory)
    theory_cats = ['math.ST', 'stat.TH', 'stat.ML', 'math.OC', 'cs.LG']
    arxiv_papers = search_arxiv(args.problem, max_results=15, categories=theory_cats)
    print(f"   Found {len(arxiv_papers)} papers on arXiv")
    
    if args.search_only:
        for i, p in enumerate(arxiv_papers[:10], 1):
            print(f"   {i}. {p['title'][:60]}...")
        return
    
    # 2. Get AI analysis
    print("\n🤖 Step 2: Generating theoretical analysis...")
    perplexity_result = search_perplexity(
        THEORY_ANALYSIS_PROMPT.format(problem=args.problem),
        academic_focus=True
    )
    
    analysis = perplexity_result.get('summary', '')
    
    if not analysis:
        print("   ⚠️ Could not generate AI analysis. Using template...")
        analysis = f"""
\\section{{Problem Formulation}}

% TODO: Fill in problem-specific formulation

\\section{{Identifiability}}

% TODO: Establish identifiability conditions

\\section{{Convergence Analysis}}

% TODO: Derive convergence rates

{compute_fisher_info_template()}
"""
    
    # 3. Generate theory document
    print("\n📝 Step 3: Generating theory.tex...")
    
    if args.output:
        output_dir = Path(args.output)
    else:
        output_dir = Path(f"experiments/{args.topic}/theory")
    
    tex_path = generate_theory_tex(args.problem, analysis, arxiv_papers, output_dir)
    
    print(f"\n✅ Theory document generated!")
    print(f"   📄 LaTeX: {tex_path}")
    print(f"   📚 BibTeX: {output_dir / 'related_papers.bib'}")
    print(f"\n   To compile: cd {output_dir} && pdflatex theoretical_analysis.tex")


if __name__ == '__main__':
    main()
