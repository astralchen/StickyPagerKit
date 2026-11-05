"""只读四组干预结果；统计调用次数，明确区分模型等价和静态像素等价。"""
import json,collections
from pathlib import Path
base=Path(__file__).resolve().parent
reports=json.loads((base/'focused/reports.json').read_text())
by={r['experiment']:r for r in reports}
assert len(by)==4 and all(not r['mainThreadCheckerLoaded'] for r in reports)
result={'natural':[],'sameColor':[],'stateMatrix':[],'stateCycle':[]}
def counts(events):
 return dict(collections.Counter(e['name'] for e in events))
def phases(events):
 return {phase:counts([e for e in events if e['phase']==phase]) for phase in sorted({e['phase'] for e in events})}
for report,output,points in [('natural-factorial','natural',24),('same-color','sameColor',12)]:
 for row in by[report]['rows']:
  arm=row['arm'];c=counts(row['events'])
  assert c.get('explicitTint',0)==(points if arm in ['tint','both'] else 0)
  assert c.get('explicitConfiguration',0)==(points if arm in ['configuration','both'] else 0)
  if report=='natural-factorial':assert len(row['points'])==24 and [p['point'] for p in row['points']]==list(range(1,25))
  result[output].append({'arm':arm,'counts':c,'phases':phases(row['events']),'final':row.get('final',row.get('model'))})
# Validate the intended normal-state reference, independently of observer/reference equality.
natural_both=next(r for r in by['natural-factorial']['rows'] if r['arm']=='both')['final']
assert natural_both['tint']==[0,0,1,1] and natural_both['foreground']==[0,0,1,1]
assert natural_both['imageTint']==[0,0,1,1] and natural_both['titleColor']==[1,0,0,1]
for row in by['same-color']['rows']:
 assert all(row['model'][k]==[1,0,0,1] for k in ['tint','foreground','imageTint','titleColor'])
for report,output in [('state-matrix','stateMatrix'),('state-cycle','stateCycle')]:
 rows=by[report]['rows']
 # State-cycle contains repeated normal states; retain position as part of identity.
 armRows={arm:[r for r in rows if r['arm']==arm] for arm in ['none','tint','configuration','both']}
 assert len({len(v) for v in armRows.values()})==1
 for arm,values in armRows.items():
  for index,(row,baseline) in enumerate(zip(values,armRows['both'])):
   assert row['state']==baseline['state'] and row.get('progress')==baseline.get('progress')
   diff={phase:[key for key,value in row[phase].items() if value!=baseline[phase][key]] for phase in ['immediate','natural','afterLayout']}
   result[output].append({'arm':arm,'position':index,'state':row['state'],'progress':row.get('progress'),'modelDifferencesFromBoth':diff,'staticPixelsMatchBoth':row['renderedSHA256']==baseline['renderedSHA256'],'counts':counts(row.get('naturalEvents',row.get('events',[]))),'phases':phases(row.get('naturalEvents',row.get('events',[])))})
result['boundaries']=['counts in diagnostic subclass are not CPU timings','static layer PNG equality is not compositor or gesture equivalence','all arms compare to an untouched UIButton of the same arm; ablation differences from both are findings, not weakened assertions','this fixed-title raster-template fixture does not prove every StickyPagerKit content/trait state']
(base/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
for section in ['natural','sameColor']:
 for r in result[section]:print(section,r['arm'],r['counts'],r['phases'])
for section in ['stateMatrix','stateCycle']:
 for arm in ['none','tint','configuration','both']:
  rows=[r for r in result[section] if r['arm']==arm]
  print(section,arm,'pixels match',sum(r['staticPixelsMatchBoth'] for r in rows),'/',len(rows),'diff keys',sorted({k for r in rows for v in r['modelDifferencesFromBoth'].values() for k in v}))
