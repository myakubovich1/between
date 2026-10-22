import {createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT} from "jose";
import {ApiError} from "./validation.ts";
const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
export async function revokeApple(code: string, expectedSubject: string) {
  const clientID=Deno.env.get("APPLE_CLIENT_ID"), teamID=Deno.env.get("APPLE_TEAM_ID"), keyID=Deno.env.get("APPLE_KEY_ID"), pem=Deno.env.get("APPLE_PRIVATE_KEY")?.replaceAll("\\n","\n");
  if(!clientID||!teamID||!keyID||!pem) throw new ApiError(503,"Account deletion needs the owner’s Apple token-revocation configuration. Your account has not been deleted.");
  const key=await importPKCS8(pem,"ES256");
  const secret=await new SignJWT({}).setProtectedHeader({alg:"ES256",kid:keyID}).setIssuer(teamID).setSubject(clientID).setAudience("https://appleid.apple.com").setIssuedAt().setExpirationTime("5m").sign(key);
  const params = new URLSearchParams({client_id:clientID,client_secret:secret,grant_type:"authorization_code",code});
  const response=await fetch("https://appleid.apple.com/auth/token",{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:params,signal:AbortSignal.timeout(15_000)});
  if(!response.ok)throw new ApiError(409,"Apple couldn’t confirm deletion. Continue with Apple again to obtain a fresh authorization.");
  const tokens=await response.json();
  const {payload}=await jwtVerify(tokens.id_token,appleKeys,{issuer:"https://appleid.apple.com",audience:clientID});
  if(payload.sub!==expectedSubject)throw new ApiError(403,"Use the same Apple account that you signed in with.");
  if(!tokens.refresh_token)throw new ApiError(502,"Apple did not provide the authorization needed for revocation. Please retry.");
  const revoked=await fetch("https://appleid.apple.com/auth/revoke",{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:new URLSearchParams({client_id:clientID,client_secret:secret,token:tokens.refresh_token,token_type_hint:"refresh_token"}),signal:AbortSignal.timeout(15_000)});
  if(!revoked.ok)throw new ApiError(502,"Apple authorization could not be revoked. Your account was not deleted; please retry.");
  // Codes, tokens and keys remain only in memory and are never logged or persisted.
}
