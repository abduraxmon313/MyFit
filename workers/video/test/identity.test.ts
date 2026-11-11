import { describe, expect, it } from "vitest";
import { exportPKCS8, generateKeyPair, jwtVerify } from "jose";
import { IdentityRest } from "../src/identity";

const { publicKey, privateKey } = await generateKeyPair("RS256", { extractable: true });
const account = {
  client_email: "worker@myfit-d6275.iam.gserviceaccount.com",
  private_key: await exportPKCS8(privateKey),
};
const BASE = "https://identitytoolkit.googleapis.com/v1/projects/myfit-d6275";

function google(handler: (path: string, body: any) => Response) {
  const paths: string[] = [];
  const fetcher = (async (url: RequestInfo | URL, init: RequestInit = {}) => {
    const href = String(url);
    if (href === "https://oauth2.googleapis.com/token") {
      return Response.json({ access_token: "ya29", expires_in: 3600 });
    }
    const path = href.replace(BASE, "");
    paths.push(path);
    return handler(path, JSON.parse(String(init.body)));
  }) as typeof fetch;
  return { paths, fetcher };
}

describe("IdentityRest", () => {
  it("returns the existing UID for a phone number", async () => {
    const g = google((path, body) => {
      expect(body).toEqual({ phoneNumber: ["+998901234567"] });
      return Response.json({ users: [{ localId: "old-uid" }] });
    });
    const id = new IdentityRest("myfit-d6275", account, g.fetcher);
    expect(await id.uidForPhone("+998901234567")).toBe("old-uid");
    expect(g.paths).toEqual(["/accounts:lookup"]);
  });

  it("creates a user when none exists, and handles a creation race", async () => {
    const created = google((path) =>
      path === "/accounts:lookup" ? Response.json({}) : Response.json({ localId: "new-uid" }),
    );
    expect(await new IdentityRest("myfit-d6275", account, created.fetcher).uidForPhone("+998901234567")).toBe(
      "new-uid",
    );
    expect(created.paths).toEqual(["/accounts:lookup", "/accounts"]);

    let lookups = 0;
    const race = google((path) =>
      path === "/accounts:lookup"
        ? Response.json(++lookups === 1 ? {} : { users: [{ localId: "winner" }] })
        : Response.json({ error: { message: "PHONE_NUMBER_EXISTS" } }, { status: 400 }),
    );
    expect(await new IdentityRest("myfit-d6275", account, race.fetcher).uidForPhone("+998901234567")).toBe("winner");
  });

  it("refuses disabled users and reports a missing IAM role", async () => {
    const disabled = google(() => Response.json({ users: [{ localId: "u", disabled: true }] }));
    await expect(new IdentityRest("p1234", account, disabled.fetcher).uidForPhone("+998901234567")).rejects.toMatchObject({
      status: 403,
      reason: "user-disabled",
    });
    const denied = google(() => Response.json({ error: { message: "PERMISSION_DENIED" } }, { status: 403 }));
    await expect(new IdentityRest("p1234", account, denied.fetcher).uidForPhone("+998901234567")).rejects.toMatchObject({
      reason: "auth-misconfigured",
    });
  });

  it("signs Firebase custom tokens with the service account", async () => {
    const id = new IdentityRest("myfit-d6275", account, google(() => Response.json({})).fetcher);
    const token = await id.customToken("old-uid");
    const { payload } = await jwtVerify(token, publicKey, {
      issuer: account.client_email,
      subject: account.client_email,
      audience: "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit",
    });
    expect(payload.uid).toBe("old-uid");
    expect((payload.exp as number) - (payload.iat as number)).toBe(3600);
  });
});
