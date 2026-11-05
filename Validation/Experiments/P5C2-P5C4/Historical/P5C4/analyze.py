"""只读等价性判定：配置表示、可观察模型、最终静态像素分开。"""
import json,collections
from pathlib import Path
base=Path(__file__).resolve().parent
reports=json.loads((base/'focused/reports.json').read_text())
by={r['experiment']:r for r in reports}
assert len(by)==4 and all(not r['mainThreadCheckerLoaded'] for r in reports)
def diff(pair,key):
 a,b=[x[key] for x in pair]
 return {k:{'baseline':a[k],'candidate':b[k]} for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}
def counts(events):return dict(collections.Counter(e['name'] for e in events))
result={'snapshots':[],'natural':[]}
for experiment,total in [('explicit-matrix',24),('state-restoration',13),('inheritance',11)]:
 assert len(by[experiment]['rows'])==total
 for row in by[experiment]['rows']:
  result['snapshots'].append({'experiment':experiment,'name':row['name'],'metadata':row['metadata'],'presentationDifferences':{phase:diff(row[phase],'presentation') for phase in ['immediate','natural','afterLayout']},'representationDifferences':{phase:diff(row[phase],'representation') for phase in ['immediate','natural','afterLayout']},'pixelsEqual':row['hashes'][0]==row['hashes'][1],'counts':[counts(e) for e in row['naturalEvents']]})
for row in by['natural-progress']['rows']:
 assert len(row['points'])==24 and [p['point'] for p in row['points']]==list(range(1,25))
 points=[{'point':p['point'],'immediate':diff(p['immediate'],'presentation'),'beforeNextWrite':diff(p['before'],'presentation')} for p in row['points']]
 c=[counts(e) for e in row['events']]
 assert all(x['explicitTint']==24 for x in c)
 assert c[0]['explicitConfiguration']==24 and c[1].get('explicitConfiguration',0)==(24 if row['combined'] else 0)
 result['natural'].append({'combined':row['combined'],'counts':c,'points':points,'finalPresentationDifferences':diff(row['final'],'presentation'),'finalRepresentationDifferences':diff(row['final'],'representation')})
result['summary']={}
for experiment in ['explicit-matrix','state-restoration','inheritance']:
 rows=[r for r in result['snapshots'] if r['experiment']==experiment]
 result['summary'][experiment]={'records':len(rows),'equalPixels':sum(r['pixelsEqual'] for r in rows),'equalPresentation':{p:sum(not r['presentationDifferences'][p] for r in rows) for p in ['immediate','natural','afterLayout']},'differingKeys':sorted({k for r in rows for d in r['presentationDifferences'].values() for k in d})}
result['notes']=['diagnostic tests passing validates experiment controls, not cross-variant equivalence','imageTint/buttonTint are observable UIKit view models, not automatically a StickyPagerKit public API guarantee','nil configuration foreground is representation and not counted as a presentation failure','static layer rendering and display callbacks are not compositor/gesture acceptance','no inference of performance from counts']
(base/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result['summary'],ensure_ascii=False,indent=2))
for r in result['natural']:print('natural combined',r['combined'],r['counts'],'immediate diff',sum(bool(p['immediate']) for p in r['points']),'next diff',sum(bool(p['beforeNextWrite']) for p in r['points']),'final',r['finalPresentationDifferences'])
for r in result['snapshots']:
 if any(r['presentationDifferences'].values()) or not r['pixelsEqual']:print(r['experiment'],r['name'],'diffs',{p:list(v) for p,v in r['presentationDifferences'].items()},'pixels',r['pixelsEqual'])
