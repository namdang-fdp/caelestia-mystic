const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const c={};vm.createContext(c);
vm.runInContext(fs.readFileSync(path.join(__dirname,'ToolsLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),c);
test('todos: add, trim, limit, toggle, remove, clear',()=>{
 let t=c.addTodo([],'  buy milk  ','1');
 assert.equal(t.length,1);assert.equal(t[0].text,'buy milk');
 assert.equal(c.addTodo(t,'   ','2').length,1);
 t=c.addTodo(t,'x'.repeat(500),'2');assert.equal(t[1].text.length,120);
 t=c.toggleTodo(t,'1');assert.equal(t[0].done,true);
 assert.equal(c.openCount(t),1);
 assert.deepEqual([...c.sortedTodos(t).map(x=>x.id)],['2','1']);
 assert.deepEqual([...c.clearDone(t).map(x=>x.id)],['2']);
 assert.deepEqual([...c.removeTodo(t,'2').map(x=>x.id)],['1']);
 let big=[];for(let i=0;i<60;i++)big=c.addTodo(big,'t'+i,String(i));assert.equal(big.length,50);
});
test('adapter sequence objects are accepted',()=>{
 assert.equal(c.addTodo({0:{id:'a',text:'x',done:false},length:1},'y','b').length,2);
 assert.equal(c.list('str').length,0);
});
test('keep awake deadline and label',()=>{
 assert.equal(c.awakeDeadline(1000,30),1000+1800000);assert.equal(c.awakeDeadline(1000,0),0);
 assert.equal(c.awakeLabel(0,5),'');
 assert.equal(c.awakeLabel(100*60000,0),'1h 40m');assert.equal(c.awakeLabel(5*60000,0),'5m');assert.equal(c.awakeLabel(10,20),'0m');
});
test('eye break waits while busy',()=>{
 assert.equal(c.eyeBreakDue(0,20*60000,20,false),true);
 assert.equal(c.eyeBreakDue(0,20*60000,20,true),false);
 assert.equal(c.eyeBreakDue(0,19*60000,20,false),false);
});
test('box breathing cycles through four equal phases',()=>{
 assert.equal(c.breathe(0,4000).phase,'inhale');assert.equal(c.breathe(4000,4000).phase,'hold');
 assert.equal(c.breathe(8000,4000).phase,'exhale');assert.equal(c.breathe(12000,4000).phase,'rest');
 assert.equal(c.breathe(16000,4000).phase,'inhale');
 assert.ok(Math.abs(c.breathe(3999,4000).scale-1)<.01);assert.equal(c.breathe(4500,4000).scale,1);
 assert.ok(Math.abs(c.breathe(0,4000).scale-.55)<1e-9);assert.equal(c.breathe(1000,4000).secondsLeft,3);
});
test('clock zones are validated and parsed',()=>{
 assert.equal(c.validZone('Asia/Tokyo'),true);assert.equal(c.validZone('America/Argentina/Buenos_Aires'),true);
 for (const z of ['../etc','a b','$(rm)','','Asia/Tokyo;ls']) assert.equal(c.validZone(z),false);
 const r=c.parseClockOutput('21:05|Tue|21\n09:05|Wed|09\n',[{name:'A',tz:'x'},{name:'B',tz:'y'},{name:'C',tz:'z'}]);
 assert.equal(r[0].night,true);assert.equal(r[1].night,false);assert.equal(r[2].time,'--:--');
});
