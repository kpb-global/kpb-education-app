import { PassThrough } from 'node:stream';

import { CompetitionReadinessHttpException } from '../common/competition-readiness.errors';
import { ApplicationArtifactsController } from './application-artifacts.controller';
import type { ApplicationArtifactsService } from './application-artifacts.service';

describe('ApplicationArtifactsController', () => {
  it('returns a stable 4xx domain error when multipart file is missing', () => {
    const controller = new ApplicationArtifactsController(
      {} as ApplicationArtifactsService,
    );

    expect(() =>
      controller.completeUpload(
        'version-1',
        undefined,
        { studentUser: { id: 'student-1' } },
      ),
    ).toThrow(CompetitionReadinessHttpException);

    try {
      controller.completeUpload(
        'version-1',
        undefined,
        { studentUser: { id: 'student-1' } },
      );
    } catch (error) {
      expect(error).toMatchObject({
        status: 400,
        response: expect.objectContaining({
          code: 'ARTIFACT_KIND_NOT_ALLOWED',
        }),
      });
    }
  });

  it('serves private evidence with anti-cache, anti-sniff and sandbox headers', async () => {
    const stream = new PassThrough();
    const artifacts = {
      getDownload: jest.fn().mockResolvedValue({
        fileName: 'preuve.pdf',
        object: {
          mimeType: 'application/pdf',
          sizeBytes: 12,
          stream,
        },
      }),
    } as unknown as ApplicationArtifactsService;
    const controller = new ApplicationArtifactsController(artifacts);
    const headers = new Map<string, string | number>();
    const response = new PassThrough() as any;
    response.headersSent = false;
    response.setHeader = jest.fn((name: string, value: string | number) => {
      headers.set(name, value);
    });
    response.status = jest.fn().mockReturnValue(response);

    const completion = controller.download(
      'version-1',
      { studentUser: { id: 'student-1' } },
      response,
    );
    stream.end(Buffer.from('test'));
    await completion;

    expect(artifacts.getDownload).toHaveBeenCalledWith(
      'student-1',
      'version-1',
    );
    expect(headers.get('Cache-Control')).toBe(
      'private, no-store, max-age=0',
    );
    expect(headers.get('Pragma')).toBe('no-cache');
    expect(headers.get('Expires')).toBe('0');
    expect(headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(headers.get('Content-Security-Policy')).toBe(
      "default-src 'none'; sandbox",
    );
    expect(headers.get('Cross-Origin-Resource-Policy')).toBe('same-origin');
  });
});
