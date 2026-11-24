const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const c={};vm.createContext(c);
vm.runInContext(fs.readFileSync(path.join(__dirname,'DevLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),c);
test('durations read naturally',()=>{
 assert.equal(c.duration(45),'45s');assert.equal(c.duration(134),'2m 14s');assert.equal(c.duration(3900),'1h 05m');
 assert.equal(c.duration(-3),'0s');assert.equal(c.duration('x'),'0s');
});
test('one line collapses whitespace and truncates',()=>{
 assert.equal(c.oneLine('npm   run\n build',48),'npm run build');
 assert.equal(c.oneLine('x'.repeat(100),10),'xxxxxxxxx…');assert.equal(c.oneLine(null,5),'');
});
test('command pill reflects success and failure',()=>{
 const ok=c.commandPill(0,134,'npm test');
 assert.equal(ok.title,'npm test');assert.equal(ok.detail,'2m 14s');assert.equal(ok.icon,'check');assert.equal(ok.tint,'green');
 const bad=c.commandPill(2,40,'cargo   build');
 assert.equal(bad.title,'cargo build');assert.equal(bad.detail,'exit 2');assert.equal(bad.icon,'close');assert.equal(bad.tint,'red');
 assert.equal(c.commandPill(2,40,'').title,'Terminal');
});
test('ipc arguments are validated',()=>{
 assert.equal(c.validExit(0),true);assert.equal(c.validExit(256),false);assert.equal(c.validExit(-1),false);assert.equal(c.validExit(1.5),false);
 assert.equal(c.validSeconds(30),true);assert.equal(c.validSeconds(-1),false);assert.equal(c.validSeconds(NaN),false);
});

const pr=(n,ci,review='')=>({repo:'me/app',number:n,title:'T'+n,ci,review});
test('the first read is only a baseline',()=>{
 const r=c.diffPulls(null,{prs:[pr(1,'failing')],merged:[]});
 assert.equal(r.events.length,0);assert.equal(r.state.open['me/app#1'].ci,'failing');
});
test('CI and review transitions produce one event each',()=>{
 let r=c.diffPulls(null,{prs:[pr(1,'pending')],merged:[]});
 r=c.diffPulls(r.state,{prs:[pr(1,'failing')],merged:[]});
 assert.deepEqual([...r.events.map(e=>e.type)],['ci-failed']);
 r=c.diffPulls(r.state,{prs:[pr(1,'failing')],merged:[]});assert.equal(r.events.length,0);
 r=c.diffPulls(r.state,{prs:[pr(1,'passing','APPROVED')],merged:[]});
 assert.deepEqual([...r.events.map(e=>e.type)],['ci-passed','approved']);
 r=c.diffPulls(r.state,{prs:[pr(1,'passing','CHANGES_REQUESTED')],merged:[]});
 assert.deepEqual([...r.events.map(e=>e.type)],['changes']);
});
test('a PR with no checks that gains a passing run is not announced',()=>{
 let r=c.diffPulls(null,{prs:[pr(1,'none')],merged:[]});
 r=c.diffPulls(r.state,{prs:[pr(1,'passing')],merged:[]});assert.equal(r.events.length,0);
});
test('merged is announced once, and only for a PR that was open',()=>{
 let r=c.diffPulls(null,{prs:[pr(1,'passing')],merged:[{repo:'me/app',number:7,title:'old'}]});
 r=c.diffPulls(r.state,{prs:[],merged:[{repo:'me/app',number:1,title:'T1'},{repo:'me/app',number:7,title:'old'}]});
 assert.deepEqual([...r.events.map(e=>e.type+e.pr.number)],['merged1']);
 r=c.diffPulls(r.state,{prs:[],merged:[{repo:'me/app',number:1,title:'T1'}]});assert.equal(r.events.length,0);
});
test('pull pills name the repo and tint by outcome',()=>{
 const p=c.pullPill({type:'ci-failed',pr:pr(12,'failing')});
 assert.equal(p.title,'CI failed');assert.equal(p.tint,'red');assert.equal(p.detail,'app #12 · T12');
 assert.equal(c.pullPill({type:'merged',pr:pr(3,'passing')}).tint,'purple');
 assert.equal(c.anyFailing({prs:[pr(1,'passing'),pr(2,'failing')]}),true);assert.equal(c.anyFailing(null),false);
});
