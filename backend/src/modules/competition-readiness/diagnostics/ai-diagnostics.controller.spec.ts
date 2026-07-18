import type { Response } from "express";

import { AiDiagnosticsController } from "./ai-diagnostics.controller";
import type { AiDiagnosticsService } from "./ai-diagnostics.service";

describe("AiDiagnosticsController", () => {
  it("passes the validated idempotency key to the service unchanged", async () => {
    const create = jest.fn().mockResolvedValue({
      statusCode: 201,
      body: { id: "diagnostic-1", status: "succeeded" },
    });
    const controller = new AiDiagnosticsController({
      create,
    } as unknown as AiDiagnosticsService);
    const status = jest.fn();

    const result = await controller.create(
      "workspace-1",
      { language: "fr", consentReceiptId: "consent-1" },
      "  retry-key-1  ",
      { studentUser: { id: "student-1" } },
      { status } as unknown as Response,
    );

    expect(create).toHaveBeenCalledWith(
      "student-1",
      "workspace-1",
      { language: "fr", consentReceiptId: "consent-1" },
      "retry-key-1",
    );
    expect(status).toHaveBeenCalledWith(201);
    expect(result).toEqual({ id: "diagnostic-1", status: "succeeded" });
  });

  it("rejects a missing key before invoking the service", async () => {
    const create = jest.fn();
    const controller = new AiDiagnosticsController({
      create,
    } as unknown as AiDiagnosticsService);

    await expect(
      controller.create(
        "workspace-1",
        { language: "fr" },
        undefined,
        { studentUser: { id: "student-1" } },
        { status: jest.fn() } as unknown as Response,
      ),
    ).rejects.toMatchObject({
      status: 400,
      response: expect.objectContaining({ code: "IDEMPOTENCY_KEY_REQUIRED" }),
    });
    expect(create).not.toHaveBeenCalled();
  });
});
