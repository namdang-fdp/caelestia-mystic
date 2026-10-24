const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const logic={};
vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname,'ActivityLogic.js'),'utf8').replace(/^\.pragma library\s*/,'').trim(),logic);
test('deadline countdown catches up after sleep and never becomes negative',()=>{
 assert.equal(logic.remaining(100000,20000),80000);
 assert.equal(logic.remaining(100000,150000),0);
});
test('paused timer keeps its saved remainder regardless of wall clock',()=>{
 assert.equal(logic.timerRemaining(false,999,32000,1000000),32000);
});
test('duration rejects missing, nonnumeric and out of range input',()=>{
 for(const value of [null,'',NaN,'abc',0,-1,181]) assert.equal(logic.durationMinutes(value),0);
 assert.equal(logic.durationMinutes('25'),25);
 assert.equal(logic.durationMinutes(5.5),0);
});
test('Pomodoro alternates work and breaks, long break after fourth completed focus',()=>{
 assert.equal(logic.nextPhase('focus',1),'break');
 assert.equal(logic.nextPhase('focus',4),'longBreak');
 assert.equal(logic.nextPhase('break',4),'focus');
 assert.equal(logic.nextPhase('longBreak',4),'focus');
});
test('battery warning only on real discharging battery and escalates at 10%',()=>{
 assert.equal(logic.batteryLevel(true,true,.2),1);
 assert.equal(logic.batteryLevel(true,true,.1),2);
 assert.equal(logic.batteryLevel(true,false,.05),0);
 assert.equal(logic.batteryLevel(false,true,.05),0);
 for(const value of [-1,NaN,null,1.2]) assert.equal(logic.batteryLevel(true,true,value),0);
});
test('temperature warning needs two samples and has 85 C recovery hysteresis',()=>{
 let s=logic.temperatureState(91,0,false); assert.equal(s.active,false); assert.equal(s.samples,1);
 s=logic.temperatureState(92,s.samples,s.active); assert.equal(s.active,true);
 s=logic.temperatureState(88,s.samples,s.active); assert.equal(s.active,true);
 s=logic.temperatureState(84,s.samples,s.active); assert.equal(s.active,false);
});
test('unknown sensor breaks consecutive hot samples and never invents a temperature',()=>{
 let s=logic.temperatureState(null,1,false); assert.equal(s.samples,0); assert.equal(s.active,false);
 s=logic.temperatureState(400,0,false); assert.equal(s.samples,0);
});
test('wheel deltas accumulate touchpad input into whole notches',()=>{
 let s=logic.wheelSteps(0,40); assert.equal(s.steps,0); assert.equal(s.rest,40);
 s=logic.wheelSteps(s.rest,90); assert.equal(s.steps,1); assert.equal(s.rest,10);
 s=logic.wheelSteps(0,-250); assert.equal(s.steps,-2); assert.equal(s.rest,-10);
 assert.equal(logic.wheelSteps(5,NaN).steps,0);
});
test('unit values are clamped and non-finite input is zero',()=>{
 assert.equal(logic.clampUnit(1.4),1); assert.equal(logic.clampUnit(-1),0); assert.equal(logic.clampUnit(NaN),0); assert.equal(logic.clampUnit(.5),.5);
});
test('resting mode cycles through available modes in both directions',()=>{
 const modes=['auto','lyrics','stats'];
 assert.equal(logic.nextRestingMode('auto',modes,1),'lyrics');
 assert.equal(logic.nextRestingMode('stats',modes,1),'auto');
 assert.equal(logic.nextRestingMode('auto',modes,-1),'stats');
 assert.equal(logic.nextRestingMode('lyrics',['auto','stats'],1),'auto');
 assert.equal(logic.nextRestingMode('lyrics',[],1),'auto');
});
test('bluetooth icons map common device classes and fall back safely',()=>{
 assert.equal(logic.bluetoothIcon('audio-headset'),'headphones');
 assert.equal(logic.bluetoothIcon('audio-card'),'speaker');
 assert.equal(logic.bluetoothIcon('input-mouse'),'mouse');
 assert.equal(logic.bluetoothIcon('phone'),'smartphone');
 assert.equal(logic.bluetoothIcon(undefined),'bluetooth');
});
