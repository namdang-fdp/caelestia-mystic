const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const c={};vm.createContext(c);
vm.runInContext(fs.readFileSync(path.join(__dirname,'ClipboardLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),c);
const e=(o)=>({label:'hello world',type:'text',pinned:false,app:'firefox',...o});
test('query tags separate kinds, apps and words',()=>{
 const q=c.parseQuery('@Image @firefox report  @');
 assert.deepEqual([...q.kinds],['image']);assert.deepEqual([...q.apps],['firefox']);assert.deepEqual([...q.words],['report','@']);
});
test('matching combines kind, app and words',()=>{
 assert.equal(c.matches(e({}),c.parseQuery('')),true);
 assert.equal(c.matches(e({type:'image'}),c.parseQuery('@image')),true);
 assert.equal(c.matches(e({}),c.parseQuery('@image')),false);
 assert.equal(c.matches(e({}),c.parseQuery('@fire hello')),true);
 assert.equal(c.matches(e({app:''}),c.parseQuery('@fire')),false);
 assert.equal(c.matches(e({pinned:true}),c.parseQuery('@pinned')),true);
 assert.equal(c.matches(e({}),c.parseQuery('nope')),false);
});
test('retention cycles and labels',()=>{
 assert.equal(c.nextRetention(0),1);assert.equal(c.nextRetention(168),0);assert.equal(c.nextRetention(5),0);
 assert.equal(c.retentionLabel(0),'Auto-delete off');assert.equal(c.retentionLabel(24),'Delete after 1 day');
});
test('stack is first in, first out without duplicates',()=>{
 let s=c.pushStack([],'1');s=c.pushStack(s,'2');s=c.pushStack(s,'1');s=c.pushStack(s,'');
 assert.deepEqual([...s],['1','2']);
 const p=c.popStack(s);assert.equal(p.next,'1');assert.deepEqual([...p.rest],['2']);
 assert.equal(c.popStack([]).next,'');
});
