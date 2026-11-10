/**
 * API error with a machine-readable `reason` (the Flutter app localizes it).
 * Reasons match the earlier Cloud Functions implementation.
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly reason: string,
    message: string,
  ) {
    super(message);
  }
}

export const unauthenticated = (reason: string, message: string) =>
  new ApiError(401, reason, message);
export const forbidden = (reason: string, message: string) =>
  new ApiError(403, reason, message);
export const invalid = (reason: string, message: string) =>
  new ApiError(400, reason, message);
export const notFound = (reason: string, message: string) =>
  new ApiError(404, reason, message);
export const precondition = (reason: string, message: string) =>
  new ApiError(409, reason, message);
export const unavailable = (reason: string, message: string) =>
  new ApiError(503, reason, message);
