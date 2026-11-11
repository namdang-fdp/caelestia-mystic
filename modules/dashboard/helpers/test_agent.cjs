const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const load=f=>{const c={};vm.createContext(c);vm.runInContext(fs.readFileSync(path.join(__dirname,f),'utf8').replace(/^\.pragma library\s*/,''),c);return c;};
const logic=load('AgentLogic.js'), act=load('ActivityLogic.js');
const now=1_000_000_000_000;
const s=(agent,session,state,ageSec=1)=>({agent,session,state,updated:now/1000-ageSec,project:'p'});

test('waiting outranks working and done never claims the notch',()=>{
 assert.equal(logic.foreground([s('claude','a','working'),s('codex','b','waiting')],now),'waiting');
 assert.equal(logic.foreground([s('claude','a','working')],now),'working');
 assert.equal(logic.foreground([s('claude','a','done')],now),'');
 assert.equal(logic.foreground([],now),'');
});
test('stale sessions are dropped so the notch cannot stick',()=>{
 assert.equal(logic.foreground([s('claude','a','working',601)],now),'');
 assert.equal(logic.foreground([s('claude','a','working',599)],now),'working');
 assert.equal(logic.live([s('claude','a','done',181)],now).length,0);
});
test('malformed entries are ignored',()=>{
 assert.equal(logic.live([null,{},{agent:'x',session:'y',state:'bogus',updated:1},s('claude','a','working')],now).length,1);
});
test('diff reports waiting and working-to-done once',()=>{
 let r=logic.diff({},[s('claude','a','working')],now);
 assert.equal(r.events.length,0);
 r=logic.diff(r.states,[s('claude','a','waiting')],now);
 assert.deepEqual([...r.events.map(e=>e.type)],['waiting']);
 r=logic.diff(r.states,[s('claude','a','waiting')],now);
 assert.equal(r.events.length,0);
 r=logic.diff(r.states,[s('claude','a','working')],now);
 r=logic.diff(r.states,[s('claude','a','done')],now);
 assert.deepEqual([...r.events.map(e=>e.type)],['done']);
 // a session first seen as done (shell restart) is not announced
 assert.equal(logic.diff({},[s('codex','z','done')],now).events.length,0);
});
test('formatting helpers',()=>{
 assert.equal(logic.compact(950),'950');assert.equal(logic.compact(12400),'12K');assert.equal(logic.compact(2300000),'2.3M');assert.equal(logic.compact(NaN),'0');
 assert.equal(logic.elapsed(59),'59s');assert.equal(logic.elapsed(3900),'1h 05m');
 assert.deepEqual([...logic.bars([{tokens:5},{tokens:10},{}])],[.5,1,0]);
 assert.equal(logic.agentName('codex'),'Codex');assert.equal(logic.agentName('gemini'),'Gemini CLI');assert.equal(logic.agentName('droid'),'Factory Droid');assert.equal(logic.agentName('zed'),'Zed');
});
test('activity: waiting beats recording, working sits between timer and media',()=>{
 const base={resizing:false,warning:false,recording:false,timerActive:false,hasAudio:false,restingMode:'auto',agent:''};
 assert.equal(act.currentActivity({...base,agent:'waiting',recording:true}),'agent');
 assert.equal(act.currentActivity({...base,agent:'waiting',warning:true}),'health');
 assert.equal(act.currentActivity({...base,agent:'working',recording:true}),'recording');
 assert.equal(act.currentActivity({...base,agent:'working',timerActive:true}),'timer');
 assert.equal(act.currentActivity({...base,agent:'working',hasAudio:true}),'agent');
 assert.equal(act.currentActivity({...base,hasAudio:true}),'media');
 assert.equal(act.activityPage('agent',{showMedia:true}),'agent');
});

test('quota severity and pet mood',()=>{
 assert.equal(logic.severity(10),'ok');assert.equal(logic.severity(70),'warn');assert.equal(logic.severity(95),'high');assert.equal(logic.severity(NaN),'ok');
 assert.equal(logic.petMood('waiting',99),'waiting');assert.equal(logic.petMood('working',95),'tired');
 assert.equal(logic.petMood('working',10),'working');assert.equal(logic.petMood('',10),'idle');
 assert.equal(logic.health(29),71);assert.equal(logic.health(150),0);assert.equal(logic.peakPercent([3,'x',71]),71);assert.equal(logic.peakPercent([]),0);
 assert.equal(logic.moodLabel('working'),'Hyped');
});
test('weeks from several agents add up per day',()=>{
 const a=[{date:'d1',tokens:5,calls:1},{date:'d2',tokens:0,calls:0}], b=[{date:'d1',tokens:7,calls:2}];
 const r=logic.sumWeeks([a,b,null]);
 assert.equal(r.length,2);assert.equal(r[0].tokens,12);assert.equal(r[0].calls,3);assert.equal(r[1].tokens,0);
 assert.equal(logic.sumWeeks([]).length,0);
});
