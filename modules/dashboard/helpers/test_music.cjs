const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const c={};vm.createContext(c);
vm.runInContext(fs.readFileSync(path.join(__dirname,'MusicLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),c);
test('extra buttons keep canonical order and drop unknown ids',()=>{
 assert.deepEqual([...c.extras(['loop','x','back15'])],['back15','loop']);
 assert.deepEqual([...c.extras({0:'shuffle',length:1})],['shuffle']);
 assert.deepEqual([...c.toggleExtra(['back15'],'loop')],['back15','loop']);
 assert.deepEqual([...c.toggleExtra(['back15'],'back15')],[]);
 assert.deepEqual([...c.toggleExtra(['back15'],'evil')],['back15']);
});
test('seek stays inside the track',()=>{
 assert.equal(c.seekTarget(100,200,15),115);assert.equal(c.seekTarget(5,200,-15),0);assert.equal(c.seekTarget(195,200,15),200);
 assert.equal(c.seekTarget(10,0,15),25);assert.equal(c.seekTarget(NaN,200,15),0);
});
test('loop cycles through three states',()=>{
 assert.equal(c.nextLoop(0),1);assert.equal(c.nextLoop(2),0);assert.equal(c.loopIcon(1),'repeat_one');assert.equal(c.loopIcon(2),'repeat');
});
test('lyric window clips at the ends',()=>{
 const w=c.lyricWindow(['a','b','c'],0,1,1);
 assert.deepEqual([...w.map(x=>x.text)],['a','b']);assert.equal(w[0].offset,0);
 assert.equal(c.lyricWindow([],0,1,1).length,0);assert.equal(c.lyricWindow(['a'],-1,1,1).length,0);
});
test('themes wrap around',()=>{
 assert.equal(c.theme(0).id,'midnight');assert.equal(c.theme(5).id,'midnight');assert.equal(c.theme(-1).id,'midnight');assert.equal(c.theme('x').id,'midnight');
});
