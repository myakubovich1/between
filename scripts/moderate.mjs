#!/usr/bin/env node
// Server operator only. Never put this credential in an app or shared screenshot.
const [action,reference]=process.argv.slice(2);
if(!['review','remove','suspend','restore'].includes(action??''))throw new Error('Usage: node scripts/moderate.mjs review | remove|suspend|restore REPORT_UUID');
const url=process.env.SUPABASE_URL,secret=process.env.SUPABASE_SERVICE_ROLE_KEY,operator=process.env.BETWEEN_OPERATOR;
if(!url||!secret)throw new Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your secure server shell.');
if(action!=='review'&&(!operator||!reference?.match(/^[0-9a-f-]{36}$/i)))throw new Error('Set BETWEEN_OPERATOR and provide a report UUID from the protected review output.');
const response=await fetch(url+'/rest/v1/rpc/'+(action==='review'?'review_flags':'moderate_report'),{method:'POST',headers:{apikey:secret,Authorization:'Bearer '+secret,'Content-Type':'application/json'},body:JSON.stringify(action==='review'?{}:{p_reference:reference,p_action:action,p_operator:operator})});
if(!response.ok)throw new Error('Moderation operation failed (HTTP '+response.status+'). Review server diagnostics without printing credentials.');
console.log(JSON.stringify(await response.json(),null,2));
