import {ApiError,isNearby,limitedJSON,uuid,validateObservation} from "./validation.ts";
import {revokeApple} from "./apple.ts";
const base=Deno.env.get("SUPABASE_URL")!;
const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const headers={"apikey":service,"Authorization":`Bearer ${service}`,"Content-Type":"application/json"};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}});
async function admin(path:string,method="GET",body?:unknown) {
  const response=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(15_000)});
  if(!response.ok){
    const error=await response.json().catch(()=>({}));const message=String(error.message??"");
    const rate=message.match(/rate_limit:(\d+)/);if(rate)throw new ApiError(429,"You’ve reported recently.",Number(rate[1]));
    if(message.includes("account_ineligible"))throw new ApiError(403,"This account can’t contribute. Sign in again or contact support.");
    if(message.includes("invalid_scope"))throw new ApiError(400,"That place or zone is no longer available.");
    if(message.includes("invalid_reference"))throw new ApiError(400,"This observation is no longer available for feedback.");
    throw new ApiError(502,"The server couldn’t complete that operation. Please retry.");
  }
  return response.status===204?{ok:true}:await response.json();
}
async function identity(req:Request,required=true) {
  const bearer=req.headers.get("authorization");
  if(!bearer){if(!required)return null;throw new ApiError(401,"Sign in with Apple to contribute.");}
  if(!/^Bearer [A-Za-z0-9_.-]+$/.test(bearer)||bearer.length>9000)throw new ApiError(401,"Your sign-in has expired. Sign in again.");
  const response=await fetch(base+"/auth/v1/user",{headers:{apikey:service,Authorization:bearer},signal:AbortSignal.timeout(15_000)});
  if(!response.ok)throw new ApiError(401,"Your sign-in has expired. Sign in again.");
  const user=await response.json();
  if(user.is_anonymous)throw new ApiError(403,"Use an Apple account to contribute.");
  // Only after the Auth server verified this JWT do we read the signed session claim.
  let claims:Record<string,unknown>;try{const part=bearer.split(".")[1].replaceAll("-","+").replaceAll("_","/");claims=JSON.parse(atob(part));}catch{throw new ApiError(401,"Invalid session.");}
  if(!uuid(user.id)||!uuid(claims.session_id))throw new ApiError(401,"A current account session is required.");
  return {id:user.id,session:claims.session_id,user,bearer};
}
Deno.serve(async(req:Request)=>{
 try {
  const path=new URL(req.url).pathname.split("between-api")[1]?.replace(/^\//,"")??"";
  if(req.method==="GET"&&path==="catalog"){
    const rows=await admin("/rest/v1/places?active=eq.true&select=document&limit=100");return json(rows.map((r:{document:unknown})=>r.document));
  }
  if(req.method==="GET"&&path==="summaries"){
    const viewer=await identity(req,false);return json(await admin("/rest/v1/rpc/read_summaries","POST",{p_viewer:viewer?.id??null}));
  }
  if(req.method==="GET"&&path==="reports/mine"){
    const viewer=(await identity(req))!;return json(await admin("/rest/v1/rpc/my_observations","POST",{p_author:viewer.id,p_session:viewer.session}));
  }
  if(req.method==="POST"&&path==="reports"){
    const viewer=(await identity(req))!;const body=await limitedJSON(req);
    if(uuid(body.idempotencyKey)) {
      const original=await admin("/rest/v1/rpc/existing_receipt","POST",{p_author:viewer.id,p_session:viewer.session,p_key:body.idempotencyKey});
      if(original)return json(original);
    }
    const observation=validateObservation(body);
    const places=await admin("/rest/v1/places?id=eq."+encodeURIComponent(observation.place)+"&active=eq.true&select=document&limit=1");
    if(!places.length)throw new ApiError(400,"Choose an active campus place.");
    // Raw coordinates are evaluated here and never sent to Postgres or logged.
    const nearby=isNearby(body.location,places[0].document.coordinate);
    return json(await admin("/rest/v1/rpc/submit_observation","POST",{p_author:viewer.id,p_session:viewer.session,p_place:observation.place,p_zone:observation.zone,p_seat:observation.seat,p_noise:observation.noise,p_key:observation.key,p_nearby:nearby}));
  }
  if(req.method==="POST"&&path==="feedback"){
    const viewer=(await identity(req))!;const body=await limitedJSON(req);
    if(!uuid(body.reference)||!["flag","block"].includes(String(body.action)))throw new ApiError(400,"Choose a valid report action.");
    return json(await admin("/rest/v1/rpc/report_feedback","POST",{p_author:viewer.id,p_session:viewer.session,p_reference:body.reference,p_action:body.action}));
  }
  if(req.method==="DELETE"&&path==="account"){
    const viewer=(await identity(req))!;const body=await limitedJSON(req);
    if(typeof body.authorizationCode!=="string"||body.authorizationCode.length>2048)throw new ApiError(400,"Continue with Apple to confirm account deletion.");
    const apple=viewer.user.identities?.find((i:{provider:string})=>i.provider==="apple");
    const subject=apple?.identity_data?.sub;
    if(!subject)throw new ApiError(403,"This account has no Apple identity to revoke. Contact the project owner.");
    // First deny new writes atomically, even from already-issued tokens.
    await admin("/rest/v1/rpc/begin_account_deletion","POST",{p_author:viewer.id,p_session:viewer.session});
    await revokeApple(body.authorizationCode,subject);
    // Hard deletion cascades contributions, flags, blocks, controls and Auth refresh sessions.
    await admin("/auth/v1/admin/users/"+viewer.id,"DELETE");
    return json({ok:true});
  }
  throw new ApiError(404,"This endpoint is not available.");
 } catch(error) {
  if(error instanceof ApiError)return json({error:error.message,...(error.retryAfter?{retryAfter:error.retryAfter}:{})},error.status);
  // Never log request bodies, JWTs, Apple codes, identity data or precise coordinates.
  return json({error:"The service is unavailable. Please try again."},503);
 }
});
