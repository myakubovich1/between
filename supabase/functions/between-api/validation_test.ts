import {ApiError,isNearby,limitedJSON,validateObservation} from './validation.ts';
const assert=(condition:unknown,message='assertion failed')=>{if(!condition)throw new Error(message);};
const now=Date.parse('2026-10-22T18:00:00Z');
const valid=()=>({placeID:'marston',zoneID:null,seat:1,noise:null,idempotencyKey:'00000000-0000-4000-8000-000000000001',reconfirmedAt:new Date(now).toISOString()});
Deno.test('accepted enums only, no client author/timestamp/state trust',()=>{
 const result=validateObservation({...valid(),author:'forged',acceptedAt:'2099',nearby:true},now);assert(!('author' in result));assert(!('acceptedAt' in result));
 for(const field of [{seat:4},{seat:-1},{seat:1.1},{noise:3},{noise:'1'},{idempotencyKey:'x'}]){let failed=false;try{validateObservation({...valid(),...field},now);}catch(e){failed=e instanceof ApiError;}assert(failed);}
});
Deno.test('late drafts require an explicit fresh confirmation',()=>{
 for(const date of [new Date(now-120001).toISOString(),new Date(now+31000).toISOString(),'invalid']){let failed=false;try{validateObservation({...valid(),reconfirmedAt:date},now);}catch(e){failed=e instanceof ApiError&&e.status===409;}assert(failed);}
});
Deno.test('nearby heuristic validates age, accuracy, radius and finite coordinates',()=>{
 const coordinate={latitude:29.647966,longitude:-82.3439126};const sample={...coordinate,accuracy:30,sampledAt:new Date(now-1000).toISOString()};assert(isNearby(sample,coordinate,now));
 for(const patch of [{accuracy:101},{accuracy:-1},{latitude:90},{longitude:Infinity},{sampledAt:new Date(now-121000).toISOString()},{sampledAt:new Date(now+6000).toISOString()},{latitude:'29.647966'}])assert(!isNearby({...sample,...patch},coordinate,now));
 assert(!isNearby(sample,null,now));assert(!isNearby(null,coordinate,now));
});
Deno.test('streamed body limit cannot be bypassed without content-length',async()=>{
 let failed=false;try{await limitedJSON(new Request('https://example.test',{method:'POST',body:JSON.stringify({x:'a'.repeat(5000)})}));}catch(e){failed=e instanceof ApiError&&e.status===413;}assert(failed);
 const decoded=await limitedJSON(new Request('https://example.test',{method:'POST',body:JSON.stringify(valid())}));assert(decoded.seat===1);
});
