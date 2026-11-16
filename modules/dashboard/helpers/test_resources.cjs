const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
// Values built inside the vm context have another Object prototype; compare them as plain JSON.
const D=(a,b)=>assert.deepEqual(JSON.parse(JSON.stringify(a)),b);
const c={};vm.createContext(c);
vm.runInContext(fs.readFileSync(path.join(__dirname,'ResourceLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),c);

test('severity thresholds at 0.70/0.85/0.90 and swap 0.5',()=>{
 assert.equal(c.severity('ram',0.69),'ok');
 assert.equal(c.severity('ram',0.70),'warm');
 assert.equal(c.severity('ram',0.85),'hot');
 assert.equal(c.severity('cpu',0.70),'warm');
 assert.equal(c.severity('cpu',0.89),'warm');
 assert.equal(c.severity('cpu',0.90),'hot');
 assert.equal(c.severity('swap',0.49),'ok');
 assert.equal(c.severity('swap',0.5),'hot');
 assert.equal(c.severity('ram',NaN),'ok');
 assert.equal(c.severity('ram',Infinity),'ok');
});
test('swap total 0 is ok and fraction(5,0) is 0',()=>{
 assert.equal(c.fraction(5,0),0);
 assert.equal(c.fraction(5,-1),0);
 assert.equal(c.fraction(1,4),0.25);
 assert.equal(c.severity('swap',c.fraction(0,0)),'ok');
});
test('sortGroups by ram then cpu is stable and does not mutate',()=>{
 const g=[{name:'b',ram_kb:10,cpu_percent:5},{name:'a',ram_kb:10,cpu_percent:50},{name:'c',ram_kb:99,cpu_percent:1}];
 D(c.sortGroups(g,'ram').map(x=>x.name),['c','a','b']);
 D(c.sortGroups(g,'cpu').map(x=>x.name),['a','b','c']);
 D(g.map(x=>x.name),['b','a','c']);
});
test('formatKb and formatAge boundaries',()=>{
 assert.equal(c.formatKb(1023),'1023 kB');
 assert.equal(c.formatKb(1024),'1 MB');
 assert.equal(c.formatKb(524288),'512 MB');
 assert.equal(c.formatKb(1048576),'1.0 GB');
 assert.equal(c.formatKb(3565158),'3.4 GB');
 assert.equal(c.formatAge(59),'59s');
 assert.equal(c.formatAge(60),'1m');
 assert.equal(c.formatAge(3599),'59m');
 assert.equal(c.formatAge(3600),'1h');
 assert.equal(c.formatAge(5*3600+10),'5h');
 assert.equal(c.formatAge(3*86400),'3d');
});
const NOW=1_000_000_000_000;
test('agentRows joins a Claude process to its session by pid',()=>{
 const claude=[{pid:10,cwd:'/h/a',project:'a',age_s:100,ram_kb:200,orphan:false}];
 const sessions=[{agent:'claude',session:'s1',pid:10,cwd:'/h/other',state:'working'}];
 const rows=c.agentRows(claude,sessions,[],NOW);
 D(rows,[{kind:'claude',label:'a',state:'working',age_s:100,ram_kb:200,orphan:false,aggregate:false}]);
});
test('agentRows two processes sharing a cwd do not borrow state (unmatched is idle)',()=>{
 const claude=[{pid:10,cwd:'/h/a',project:'a',age_s:1,ram_kb:1,orphan:false},{pid:11,cwd:'/h/a',project:'a',age_s:2,ram_kb:2,orphan:false}];
 const sessions=[{agent:'claude',session:'s1',pid:10,cwd:'/h/a',state:'waiting'}];
 const rows=c.agentRows(claude,sessions,[],NOW);
 D(rows.map(r=>r.state),['waiting','idle']);
});
test('agentRows falls back to cwd only when exactly one process has that cwd',()=>{
 const claude=[{pid:10,cwd:'/h/a',project:'a',age_s:1,ram_kb:1,orphan:false}];
 const sessions=[{agent:'claude',session:'s1',pid:0,cwd:'/h/a',state:'working'}];
 assert.equal(c.agentRows(claude,sessions,[],NOW)[0].state,'working');
});
test('orphan flag passes through',()=>{
 const claude=[{pid:10,cwd:'/h/gone',project:'gone',age_s:9,ram_kb:3,orphan:true}];
 assert.equal(c.agentRows(claude,[],[],NOW)[0].orphan,true);
});
test('agentRows adds Codex sessions and one aggregate row',()=>{
 const sessions=[{agent:'codex',session:'x',project:'proj',cwd:'/h/proj',pid:0,state:'working',updated:(NOW-120000)/1000}];
 const groups=[{name:'Codex',ram_kb:130000,cpu_percent:0,count:4}];
 const rows=c.agentRows([],sessions,groups,NOW);
 D(rows,[
  {kind:'codex',label:'proj',state:'working',age_s:120,ram_kb:0,orphan:false,aggregate:false},
  {kind:'codex',label:'Codex',state:'',age_s:0,ram_kb:130000,orphan:false,aggregate:true}]);
});
test('triggerActive false when pressed, fullscreen, outside band, or x > strip',()=>{
 const base={x:1,y:540,width:1920,height:1080,strip:4,bandStart:0.15,bandEnd:0.85,pressed:false,fullscreen:false};
 assert.equal(c.triggerActive(base),true);
 assert.equal(c.triggerActive({...base,pressed:true}),false);
 assert.equal(c.triggerActive({...base,fullscreen:true}),false);
 assert.equal(c.triggerActive({...base,x:5}),false);
 assert.equal(c.triggerActive({...base,y:100}),false);
 assert.equal(c.triggerActive({...base,y:1000}),false);
 assert.equal(c.triggerActive({...base,y:162}),true);
});
test('inPanel respects slack',()=>{
 assert.equal(c.inPanel(100,100,0,360,50,500,0),true);
 assert.equal(c.inPanel(365,100,0,360,50,500,0),false);
 assert.equal(c.inPanel(365,100,0,360,50,500,10),true);
 assert.equal(c.inPanel(100,45,0,360,50,500,10),true);
 assert.equal(c.inPanel(100,30,0,360,50,500,10),false);
});
