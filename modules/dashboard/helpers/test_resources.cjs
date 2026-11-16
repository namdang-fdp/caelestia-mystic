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

// ---- v2: history, alerts, attention, confirm ----
const MEM='MemTotal:       16000000 kB\nMemFree:  100 kB\nMemAvailable:    4000000 kB\nSwapTotal:       8000000 kB\nSwapFree:        6000000 kB\n';
test('parseMeminfo reads kb fields and tolerates missing ones',()=>{
 D(c.parseMeminfo(MEM),{total_kb:16000000,available_kb:4000000,swap_total_kb:8000000,swap_free_kb:6000000});
 D(c.parseMeminfo('MemFree: 1 kB\n'),{total_kb:0,available_kb:0,swap_total_kb:0,swap_free_kb:0});
 D(c.parseMeminfo(''),{total_kb:0,available_kb:0,swap_total_kb:0,swap_free_kb:0});
});
test('parseCpuStat and cpuPercent over two samples',()=>{
 const a=c.parseCpuStat('cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 1 2 3\n');
 assert.equal(a.total,1000);assert.equal(a.idle,800);
 const b=c.parseCpuStat('cpu  150 0 150 800 100 0 0 0 0 0\n');
 assert.equal(b.total,1200);assert.equal(b.idle,900);
 assert.equal(c.cpuPercent(a,b),50);
});
test('cpuPercent is 0 without a previous sample or progress',()=>{
 const a=c.parseCpuStat('cpu  100 0 100 700 100 0 0 0 0 0');
 assert.equal(c.cpuPercent(null,a),0);
 assert.equal(c.cpuPercent(a,a),0);
 D(c.parseCpuStat('garbage'),{total:0,idle:0});
});
test('ring caps length and stores non-finite as 0',()=>{
 D(c.ring([1,2,3],4,3),[2,3,4]);
 D(c.ring([],NaN,3),[0]);
 D(c.ring([1],Infinity,3),[1,0]);
});
test('sparkPoints spreads x, inverts y and clamps',()=>{
 D(c.sparkPoints([0,50,100],100,40,100),[{x:0,y:40},{x:50,y:20},{x:100,y:0}]);
 D(c.sparkPoints([150,-5],10,10,100),[{x:0,y:0},{x:10,y:10}]);
 D(c.sparkPoints([],10,10,100),[]);
 D(c.sparkPoints([50],10,10,100),[{x:10,y:5}]);
});
const HOT={ramFrac:0.9,swapFrac:0.1},COOL={ramFrac:0.1,swapFrac:0.1},SWAP={ramFrac:0.1,swapFrac:0.6};
const runAlerts=(samples,step=30000)=>{let s=null,fires=[];samples.forEach((x,i)=>{const r=c.alertStep(s,x,i*step);s=r.state;fires.push(r.fire);});return fires;};
test('a single hot sample does not alert',()=>{
 D(runAlerts([HOT]),[null]);
 D(runAlerts([HOT,HOT]),[null,null]);
});
test('three consecutive hot samples alert once then stay quiet inside 30 minutes',()=>{
 const fires=runAlerts([HOT,HOT,HOT,HOT,HOT]);
 D(fires,[null,null,'ram',null,null]);
 const many=Array(70).fill(HOT);               // 70 samples * 30 s = 35 min
 const f=runAlerts(many);
 assert.equal(f.filter(x=>x==='ram').length,2);
 assert.equal(f.indexOf('ram'),2);
});
test('ram and swap alert independently',()=>{
 D(runAlerts([SWAP,SWAP,SWAP]),[null,null,'swap']);
 const both={ramFrac:0.9,swapFrac:0.6};
 const f=runAlerts([both,both,both,both]);
 assert.equal(f[2],'ram');
 assert.equal(f[3],'swap');
});
test('a cool sample resets the streak',()=>{
 D(runAlerts([HOT,HOT,COOL,HOT]),[null,null,null,null]);
});
const row=(o)=>Object.assign({kind:'claude',label:'x',state:'idle',age_s:1,ram_kb:0,orphan:false,aggregate:false},o);
test('attention points to agents when idle sessions hold memory, else processes',()=>{
 assert.equal(c.attention({ram:0.5,swap:0.1},[]),null);
 const idle=[row({ram_kb:150000}),row({ram_kb:150000,state:''})];
 const a=c.attention({ram:0.9,swap:0.1},idle);
 assert.equal(a.level,'hot');assert.equal(a.tab,'agents');assert.match(a.text,/2 idle agent sessions/);
 const p=c.attention({ram:0.9,swap:0.1},[row({ram_kb:1000})]);
 assert.equal(p.tab,'processes');
 assert.equal(c.attention({ram:0.75,swap:0.1},[]).level,'warm');
 assert.equal(c.attention({ram:0.2,swap:0.6},[]).level,'warm');
 const working=[row({ram_kb:900000,state:'working'})];
 assert.equal(c.attention({ram:0.9,swap:0.1},working).tab,'processes');
});
test('confirmClick arms then fires inside the window, re-arms after it or for another key',()=>{
 let r=c.confirmClick(null,'a',1000,3000);
 assert.equal(r.fire,false);assert.equal(r.armed.key,'a');
 const r2=c.confirmClick(r.armed,'a',3999,3000);
 assert.equal(r2.fire,true);assert.equal(r2.armed,null);
 const r3=c.confirmClick(r.armed,'a',4000,3000);
 assert.equal(r3.fire,false);assert.equal(r3.armed.until,7000);
 const r4=c.confirmClick(r.armed,'b',1500,3000);
 assert.equal(r4.fire,false);assert.equal(r4.armed.key,'b');
});
test('orphanTargets keeps only orphans',()=>{
 const claude=[{pid:1,start:10,orphan:false},{pid:2,start:20,orphan:true},{pid:3,start:30,orphan:true}];
 D(c.orphanTargets(claude),[{pid:2,start:20},{pid:3,start:30}]);
 D(c.orphanTargets([]),[]);
});
test('isProtected matches exactly the listed names',()=>{
 for (const n of ['Hyprland','hyprland','quickshell','qs','systemd','pipewire','pipewire-pulse','wireplumber','dbus-daemon','dbus-broker','Xwayland']) assert.equal(c.isProtected(n),true,n);
 for (const n of ['zen-bin','claude','node','','qs2']) assert.equal(c.isProtected(n),false,n);
});
test('alertText names the top group',()=>{
 const t=c.alertText('ram',0.883,'Zen');
 assert.match(t.title,/Memory/);assert.match(t.body,/88%/);assert.match(t.body,/Zen/);
 assert.match(c.alertText('swap',0.5,'').title,/Swap/);
 assert.doesNotMatch(c.alertText('ram',0.9,'').body,/Biggest/);
});
