const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const logic={};
vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname,'DockLogic.js'),'utf8').replace(/^\.pragma library\s*/,'').trim(),logic);
const plain=v=>JSON.parse(JSON.stringify(v));
test('reorder moves a pin and keeps hidden pins in place',()=>{
 assert.deepEqual(plain(logic.reorderPinned(['a','x','b','c'],['a','b','c'],'a',2)),['b','x','c','a']);
 assert.deepEqual(plain(logic.reorderPinned(['a','b','c'],['a','b','c'],'c',0)),['c','a','b']);
 assert.deepEqual(plain(logic.reorderPinned(['a','b','c'],['a','b','c'],'b',1)),['a','b','c']);
 assert.deepEqual(plain(logic.reorderPinned(['a','b'],['a','b'],'z',0)),['a','b']);
 assert.deepEqual(plain(logic.reorderPinned(['a','b','c'],['a','b','c'],'a',99)),['b','c','a']);
});
test('drop index follows the drag distance and stays in range',()=>{
 assert.equal(logic.dropIndex(1,0,50,4),1);
 assert.equal(logic.dropIndex(1,74,50,4),2);
 assert.equal(logic.dropIndex(1,76,50,4),3);
 assert.equal(logic.dropIndex(1,-500,50,4),0);
 assert.equal(logic.dropIndex(1,500,50,4),3);
});
test('neighbours shift towards the gap left by the dragged icon',()=>{
 assert.deepEqual([0,1,2,3].map(i=>logic.dragShift(i,0,2,10)),[0,-10,-10,0]);
 assert.deepEqual([0,1,2,3].map(i=>logic.dragShift(i,3,1,10)),[0,10,10,0]);
 assert.deepEqual([0,1,2].map(i=>logic.dragShift(i,1,1,10)),[0,0,0]);
 assert.equal(logic.dragShift(-1,0,2,10),0);
});
test('scroll cycling wraps both ways',()=>{
 assert.equal(logic.cycleIndex(-1,3,1),0);
 assert.equal(logic.cycleIndex(-1,3,-1),2);
 assert.equal(logic.cycleIndex(2,3,1),0);
 assert.equal(logic.cycleIndex(0,3,-1),2);
 assert.equal(logic.cycleIndex(0,0,1),-1);
});
test('exec splitting honours quotes and escapes',()=>{
 assert.deepEqual(plain(logic.splitExec('env "A B" --flag=\\"x\\" %U')),['env','A B','--flag="x"','%U']);
 assert.deepEqual(plain(logic.splitExec('sh -c "echo \\"hi \\$HOME\\""')),['sh','-c','echo "hi $HOME"']);
 assert.deepEqual(plain(logic.splitExec('  app   ""  ')),['app','']);
});
test('multi-file field codes get every file',()=>{
 const urls=['file:///home/u/a%20b.txt','file:///tmp/c.txt'];
 assert.deepEqual(plain(logic.expandExec('code --new-window %F',urls,'Code','code')),[['code','--new-window','/home/u/a b.txt','/tmp/c.txt']]);
 assert.deepEqual(plain(logic.expandExec('zen %U',urls,'Zen','zen')),[['zen',...urls]]);
});
test('single-file field codes start one instance per file',()=>{
 const urls=['file:///a.txt','file:///b.txt'];
 assert.deepEqual(plain(logic.expandExec('gedit %f',urls,'',"")),[['gedit','/a.txt'],['gedit','/b.txt']]);
 assert.deepEqual(plain(logic.expandExec('mpv -- %u',urls,'','')),[['mpv','--','file:///a.txt'],['mpv','--','file:///b.txt']]);
 assert.deepEqual(plain(logic.expandExec('gedit %f',[urls[0]],'','')),[['gedit','/a.txt']]);
});
test('other field codes are expanded or dropped',()=>{
 assert.deepEqual(plain(logic.expandExec('app %i --name=%c 100%% %k %F',['file:///x'],'App','app-icon')),[['app','--icon','app-icon','--name=App','100%','/x']]);
 assert.deepEqual(plain(logic.expandExec('app %i %F',['file:///x'],'App','')),[['app','/x']]);
});
test('entries without file codes get the files appended',()=>{
 assert.deepEqual(plain(logic.expandExec('kitty',['file:///tmp/a'],'','')),[['kitty','/tmp/a']]);
 assert.deepEqual(plain(logic.expandExec('browser',['https://example.com'],'','')),[['browser','https://example.com']]);
 assert.deepEqual(plain(logic.expandExec('',['file:///tmp/a'],'','')),[]);
});
