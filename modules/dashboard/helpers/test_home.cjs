const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const logic={}; vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname,'HomeLogic.js'),'utf8').replace(/^\.pragma library\s*/,''),logic);
test('saved module order removes duplicate/unknown IDs and retains newly available modules',()=>{
 assert.deepEqual([...logic.order(['shelf','bad','shelf','media'])],['shelf','media','timer','agent','battery','notes']);
 assert.equal(logic.order(null).length,6);
});
test('JSON-adapter sequence objects normalize like JavaScript arrays after restart',()=>{
 const saved={0:'shelf',1:'notes',length:2};
 assert.deepEqual([...logic.order(saved)],['shelf','notes','media','timer','agent','battery']);
 assert.deepEqual([...logic.visible(null,{0:'media',length:1},false,true)],['timer','battery','notes']);
});
test('reordering respects both boundaries without mutating the saved input',()=>{
 const order=['media','timer','agent','battery','notes','shelf'];
 assert.deepEqual([...logic.move(order,'timer',-1)],['timer','media','agent','battery','notes','shelf']);
 assert.deepEqual([...logic.move(order,'media',-1)],order);
 assert.deepEqual([...logic.move(order,'shelf',1)],order);
 assert.deepEqual(order,['media','timer','agent','battery','notes','shelf']);
});
test('disabled modules and an empty shelf stay out of the overview',()=>{
 assert.deepEqual([...logic.visible(null,['timer'],false,true)],['media','battery','notes']);
 assert.deepEqual([...logic.visible(null,[],true,false)],['timer','battery','notes','shelf']);
 assert.deepEqual([...logic.visible(null,['media','timer','agent','battery','notes','shelf'],true,true)],[]);
});

test('the agent card appears only when there are sessions or statistics',()=>{
 assert.ok(![...logic.visible(null,[],false,true,false)].includes('agent'));
 assert.ok([...logic.visible(null,[],false,true,true)].includes('agent'));
 assert.deepEqual([...logic.visible(null,['agent'],false,true,true)].includes('agent'),false);
});

test('moveTo places a card at an index and clamps',()=>{
 const o=['media','timer','agent','battery','notes','shelf'];
 assert.deepEqual([...logic.moveTo(o,'shelf',0)],['shelf','media','timer','agent','battery','notes']);
 assert.deepEqual([...logic.moveTo(o,'media',99)],['timer','agent','battery','notes','shelf','media']);
 assert.deepEqual([...logic.moveTo(o,'timer',-5)].slice(0,2),['timer','media']);
 assert.deepEqual([...logic.moveTo(o,'bogus',1)],o);
 assert.deepEqual([...logic.moveTo(o,'media',1.5)],o);
});
