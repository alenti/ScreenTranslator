"""Summarize exported physical reports; never relabel Mac results as iPhone."""
import argparse, csv, json, pathlib

parser=argparse.ArgumentParser()
parser.add_argument('root',type=pathlib.Path)
args=parser.parse_args()
rows=[]
for p in sorted(args.root.rglob('report.json')):
    d=json.loads(p.read_text())
    if 'configuration' not in d: continue
    native=d.get('native',{})
    generations=[b.get('generation',b) for b in d['blocks'] if not b.get('cacheHit')]
    output=sum(g.get('generatedTokens',0) for g in generations)
    seconds=d['translationMs']/1000
    groups=d['groups']
    drawn={p['id'] for p in d['layoutMetrics']['placements']}
    area=lambda g:g['rect'][2]*g['rect'][3]
    rendered=sum(area(g) for g in groups if g['id'] in drawn)/max(1,sum(map(area,groups)))*100
    rows.append({'round':p.relative_to(args.root).parts[0],'case':d['case'],'configuration':d['configuration']['name'],'model':d['model']['filename'],
                 'modelBytes':d['model']['bytes'],'parallel':d['configuration']['parallel'],
                 'prefix':d['configuration'].get('prefix',False),'greedy':d['configuration'].get('greedy',False),
                 'packedPrefill':d['configuration'].get('batchPrefill',False),'dynamicLimit':d['configuration'].get('dynamic',False),
                 'requested':d['blocksRequested'],'translated':d['blocksTranslated'],
                 'areaCoveragePercent':d['coverage']['sourceAreaPercent'],'characterCoveragePercent':d['coverage']['charactersPercent'],
                 'generatedAreaPercent':d.get('generatedCoverage',d['coverage'])['sourceAreaPercent'],
                 'renderedAreaPercent':d.get('renderedCoverage',{}).get('sourceAreaPercent',rendered),
                 'cacheStatus':d['cacheStatus'],'cacheHits':d.get('cacheHits',0),
                 'inputTokens':sum(g.get('promptTokens',0) for g in generations),'outputTokens':output,
                 'tokenizeMs':sum(g.get('tokenizationMs',0) for g in generations),
                 'prefillMs':native.get('prefillMs',sum(g.get('prefillMs',0) for g in generations)),
                 'samplingMs':native.get('samplingMs',sum(g.get('samplingMs',0) for g in generations)),
                 'decodeMs':native.get('decodeMs',sum(g.get('decodeWallMs',g.get('decodeMs',0)) for g in generations)),
                 'ocrMs':d['ocrMs'],'groupingMs':d['groupingMs'],'renderMs':d['renderMs'],
                 'translationSeconds':seconds,'totalSeconds':d['totalMs']/1000,
                 'aggregateTokensPerSecond':output/max(seconds,1e-9),
                 'memoryEnd':d['memoryEnd'],'sampledPeakFootprintMB':native.get('peakSampleFootprintMB'),
                 'thermalBefore':d['thermalBefore'],'thermalAfter':d['thermalAfter'],
                 'memoryWarnings':d.get('memoryWarnings',0),'lowPowerMode':d['lowPowerMode'],'batteryState':d['batteryState'],
                 'errors':sum('error' in b for b in d['blocks']),'fitFailures':d['layoutMetrics']['fitFailures'],
                 'panelIntersections':d['layoutMetrics']['panelIntersections'],
                 'unrelatedSourceOverlap':d['layoutMetrics']['unrelatedSourceOverlap'],
                 'boundsViolations':d['layoutMetrics']['boundsViolations'],
                 'provenance':str(p)})
assert all(r['translated']<=r['requested'] and r['cacheHits']<=r['requested'] for r in rows)
(args.root/'performance-summary.json').write_text(json.dumps(rows,indent=2))
if rows:
    with (args.root/'performance-summary.csv').open('w') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
print(f'{len(rows)} measured runs summarized; zero runs means no performance verdict')
