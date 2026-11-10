import { AwsV4Signer } from "aws4fetch";

export interface PresignConfig {
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
}

export function encodeKey(objectKey: string) {
  return objectKey.split("/").map(encodeURIComponent).join("/");
}

/**
 * Presigned S3 `PUT` for exactly one object key. `content-type` and
 * `content-length` are part of the signature (`allHeaders`), so R2 rejects a
 * different key, type or size with 403 SignatureDoesNotMatch.
 */
export async function presignPut(
  config: PresignConfig,
  objectKey: string,
  contentType: string,
  contentLength: number,
  expiresInSeconds: number,
  now: Date = new Date(),
): Promise<string> {
  const endpoint = config.endpoint.replace(/\/+$/, "");
  // Plain http is allowed only for a local S3 test server.
  if (!/^(https:\/\/[^/]+|http:\/\/127\.0\.0\.1(:\d+)?)$/.test(endpoint)) {
    throw new Error("R2_ENDPOINT must be an https origin");
  }
  const url = new URL(`${endpoint}/${config.bucket}/${encodeKey(objectKey)}`);
  url.searchParams.set("X-Amz-Expires", String(expiresInSeconds));
  const signer = new AwsV4Signer({
    url: url.toString(),
    method: "PUT",
    headers: {
      "content-type": contentType,
      "content-length": String(contentLength),
    },
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
    service: "s3",
    region: "auto",
    signQuery: true,
    allHeaders: true,
    datetime: now.toISOString().replace(/[:-]|\.\d{3}/g, ""),
  });
  const signed = await signer.sign();
  return signed.url.toString();
}
