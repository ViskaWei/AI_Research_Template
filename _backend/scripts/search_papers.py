#!/usr/bin/env python3
"""
AI Research Template - Paper Search Engine
Author: Viska Wei

Searches for relevant academic papers using multiple sources:
1. Perplexity Sonar Pro (via OpenRouter)
2. arXiv API
3. Semantic Scholar API

Usage:
    python search_papers.py "RKHS regularization inverse problems" --max-results 10
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.parse
from datetime import datetime
from pathlib import Path

# ============================================================================
# Configuration
# ============================================================================

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
SEMANTIC_SCHOLAR_KEY = os.environ.get("SEMANTIC_SCHOLAR_KEY", "")

# ============================================================================
# arXiv Search
# ============================================================================

def search_arxiv(query: str, max_results: int = 10, categories: list = None) -> list:
    """Search arXiv for papers."""
    import xml.etree.ElementTree as ET
    
    base_url = "http://export.arxiv.org/api/query"
    
    # Build category filter
    cat_filter = ""
    if categories:
        cat_filter = " AND (" + " OR ".join([f"cat:{c}" for c in categories]) + ")"
    
    search_query = f"all:{query}{cat_filter}"
    
    params = {
        "search_query": search_query,
        "start": 0,
        "max_results": max_results,
        "sortBy": "relevance",
        "sortOrder": "descending"
    }
    
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read().decode('utf-8')
        
        # Parse XML
        root = ET.fromstring(data)
        ns = {'atom': 'http://www.w3.org/2005/Atom'}
        
        papers = []
        for entry in root.findall('atom:entry', ns):
            title = entry.find('atom:title', ns).text.strip().replace('\n', ' ')
            summary = entry.find('atom:summary', ns).text.strip()[:500]
            
            authors = []
            for author in entry.findall('atom:author', ns):
                name = author.find('atom:name', ns).text
                authors.append(name)
            
            # Get arXiv ID and URL
            arxiv_id = entry.find('atom:id', ns).text.split('/')[-1]
            pdf_link = f"https://arxiv.org/pdf/{arxiv_id}"
            
            # Get categories
            categories = [cat.get('term') for cat in entry.findall('atom:category', ns)]
            
            # Get date
            published = entry.find('atom:published', ns).text[:10]
            
            papers.append({
                'title': title,
                'authors': authors[:3],  # First 3 authors
                'abstract': summary,
                'arxiv_id': arxiv_id,
                'url': f"https://arxiv.org/abs/{arxiv_id}",
                'pdf': pdf_link,
                'categories': categories[:3],
                'date': published,
                'source': 'arXiv'
            })
        
        return papers
    
    except Exception as e:
        print(f"⚠️ arXiv search error: {e}", file=sys.stderr)
        return []


# ============================================================================
# Semantic Scholar Search
# ============================================================================

def search_semantic_scholar(query: str, max_results: int = 10) -> list:
    """Search Semantic Scholar for papers."""
    base_url = "https://api.semanticscholar.org/graph/v1/paper/search"
    
    params = {
        "query": query,
        "limit": max_results,
        "fields": "title,authors,abstract,year,citationCount,url,openAccessPdf"
    }
    
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    headers = {}
    if SEMANTIC_SCHOLAR_KEY:
        headers["x-api-key"] = SEMANTIC_SCHOLAR_KEY
    
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode('utf-8'))
        
        papers = []
        for paper in data.get('data', []):
            authors = [a.get('name', '') for a in paper.get('authors', [])[:3]]
            
            papers.append({
                'title': paper.get('title', ''),
                'authors': authors,
                'abstract': (paper.get('abstract') or '')[:500],
                'year': paper.get('year'),
                'citations': paper.get('citationCount', 0),
                'url': paper.get('url', ''),
                'pdf': paper.get('openAccessPdf', {}).get('url', ''),
                'source': 'Semantic Scholar'
            })
        
        return papers
    
    except Exception as e:
        print(f"⚠️ Semantic Scholar search error: {e}", file=sys.stderr)
        return []


# ============================================================================
# Perplexity Sonar Search (via OpenRouter)
# ============================================================================

def search_perplexity(query: str, academic_focus: bool = True) -> dict:
    """Use Perplexity Sonar Pro for academic search via OpenRouter."""
    if not OPENROUTER_API_KEY:
        print("⚠️ OPENROUTER_API_KEY not set, skipping Perplexity search", file=sys.stderr)
        return {}
    
    prompt = f"""Search for recent academic papers and research on: {query}

Focus on:
1. Key papers from the last 3 years (2022-2025)
2. Seminal/foundational papers in this area
3. Authors and research groups working on this topic
4. Main theoretical results and methods

Provide specific paper titles, authors, and years when possible."""
    
    data = {
        "model": "perplexity/sonar-pro",
        "messages": [{"role": "user", "content": prompt}]
    }
    
    try:
        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            data=json.dumps(data).encode('utf-8'),
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json"
            }
        )
        
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))
        
        content = result.get('choices', [{}])[0].get('message', {}).get('content', '')
        
        return {
            'summary': content,
            'source': 'Perplexity Sonar Pro'
        }
    
    except Exception as e:
        print(f"⚠️ Perplexity search error: {e}", file=sys.stderr)
        return {}


# ============================================================================
# BibTeX Generation
# ============================================================================

def generate_bibtex(papers: list) -> str:
    """Generate BibTeX entries for papers."""
    entries = []
    
    for i, paper in enumerate(papers):
        # Create citation key
        first_author = paper.get('authors', ['Unknown'])[0].split()[-1]
        year = paper.get('year') or paper.get('date', '')[:4] or '2024'
        title_word = paper.get('title', 'paper').split()[0].lower()
        key = f"{first_author.lower()}{year}{title_word}"
        
        authors_str = " and ".join(paper.get('authors', ['Unknown']))
        
        entry = f"""@article{{{key},
    title = {{{paper.get('title', 'Unknown Title')}}},
    author = {{{authors_str}}},
    year = {{{year}}},
    url = {{{paper.get('url', '')}}},
    note = {{Source: {paper.get('source', 'Unknown')}}}
}}"""
        entries.append(entry)
    
    return "\n\n".join(entries)


# ============================================================================
# Main
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='Search for academic papers')
    parser.add_argument('query', help='Search query')
    parser.add_argument('--max-results', type=int, default=10, help='Max results per source')
    parser.add_argument('--arxiv-cats', nargs='+', default=['stat.ML', 'math.ST', 'cs.LG'],
                        help='arXiv categories to search')
    parser.add_argument('--output', '-o', help='Output BibTeX file')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    
    args = parser.parse_args()
    
    print(f"🔍 Searching for: {args.query}\n")
    
    # Search all sources
    all_papers = []
    
    # 1. arXiv
    print("📚 Searching arXiv...")
    arxiv_papers = search_arxiv(args.query, args.max_results, args.arxiv_cats)
    all_papers.extend(arxiv_papers)
    print(f"   Found {len(arxiv_papers)} papers")
    
    # 2. Semantic Scholar
    print("📚 Searching Semantic Scholar...")
    ss_papers = search_semantic_scholar(args.query, args.max_results)
    all_papers.extend(ss_papers)
    print(f"   Found {len(ss_papers)} papers")
    
    # 3. Perplexity (for summary)
    print("🤖 Querying Perplexity Sonar Pro...")
    perplexity_result = search_perplexity(args.query)
    
    # Output
    print(f"\n{'='*60}")
    print(f"📊 Total papers found: {len(all_papers)}")
    print(f"{'='*60}\n")
    
    if args.json:
        output = {
            'query': args.query,
            'timestamp': datetime.now().isoformat(),
            'papers': all_papers,
            'perplexity_summary': perplexity_result.get('summary', '')
        }
        print(json.dumps(output, indent=2))
    else:
        # Print papers
        for i, paper in enumerate(all_papers[:10], 1):
            print(f"{i}. [{paper.get('source')}] {paper.get('title')}")
            print(f"   Authors: {', '.join(paper.get('authors', []))}")
            print(f"   URL: {paper.get('url')}")
            print()
        
        # Print Perplexity summary
        if perplexity_result:
            print("\n" + "="*60)
            print("🤖 AI Summary (Perplexity Sonar Pro):")
            print("="*60)
            print(perplexity_result.get('summary', 'No summary available'))
    
    # Save BibTeX
    if args.output:
        bibtex = generate_bibtex(all_papers)
        with open(args.output, 'w') as f:
            f.write(bibtex)
        print(f"\n✅ BibTeX saved to: {args.output}")


if __name__ == '__main__':
    main()
