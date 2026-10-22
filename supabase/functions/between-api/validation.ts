export class ApiError extends Error {
  constructor(public status: number, message: string, public retryAfter?: number) { super(message); }
}
export const uuid = (v: unknown): v is string => typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
export function validateObservation(body: Record<string, unknown>, now = Date.now()) {
  if (typeof body.placeID !== "string" || body.placeID.length > 80 || !body.placeID.length || (body.zoneID != null && (typeof body.zoneID !== "string" || body.zoneID.length > 80))) throw new ApiError(400, "Choose a valid place and zone.");
  if (!Number.isInteger(body.seat) || Number(body.seat) < 0 || Number(body.seat) > 3 || (body.noise != null && (!Number.isInteger(body.noise) || Number(body.noise) < 0 || Number(body.noise) > 2))) throw new ApiError(400, "Choose an accepted seat and sound condition.");
  if (!uuid(body.idempotencyKey)) throw new ApiError(400, "A valid submission key is required.");
  const confirmed = Date.parse(String(body.reconfirmedAt));
  if (!Number.isFinite(confirmed) || confirmed > now + 30_000 || now - confirmed > 120_000) throw new ApiError(409, "Check the conditions again before submitting this draft.");
  // Author, timestamps, moderation state and scores supplied by clients are ignored.
  return {place: body.placeID, zone: body.zoneID ?? null, seat: body.seat, noise: body.noise ?? null, key: body.idempotencyKey};
}
export function isNearby(value: unknown, coordinate: {latitude: number; longitude: number} | null, now = Date.now(), radius = 150): boolean {
  if (!value || typeof value !== "object" || !coordinate) return false;
  const l = value as Record<string, unknown>;
  const lat = Number(l.latitude), lon = Number(l.longitude), accuracy = Number(l.accuracy), sampled = Date.parse(String(l.sampledAt));
  if ([l.latitude,l.longitude,l.accuracy].some(v => typeof v !== "number") || ![lat,lon,accuracy,sampled].every(Number.isFinite) || Math.abs(lat)>90 || Math.abs(lon)>180 || accuracy<0 || accuracy>100 || sampled>now+5_000 || now-sampled>120_000) return false;
  const rad = (x: number) => x*Math.PI/180;
  const a = Math.sin(rad(lat-coordinate.latitude)/2)**2 + Math.cos(rad(lat))*Math.cos(rad(coordinate.latitude))*Math.sin(rad(lon-coordinate.longitude)/2)**2;
  return 6371000*2*Math.asin(Math.sqrt(Math.min(1,a))) <= radius;
}
export async function limitedJSON(req: Request): Promise<Record<string,unknown>> {
  if (!req.body) throw new ApiError(400,"A JSON body is required.");
  const reader = req.body.getReader();let size=0;const chunks: Uint8Array[]=[];
  while (true) { const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>4096){await reader.cancel();throw new ApiError(413,"Request is too large.");}chunks.push(value); }
  const bytes = new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  try { const body=JSON.parse(new TextDecoder().decode(bytes));if(!body||typeof body!=="object"||Array.isArray(body))throw 0;return body; } catch { throw new ApiError(400,"A JSON object is required."); }
}
