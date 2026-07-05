import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Socket } from 'net';

export type ClamdVerdict = {
  ok: boolean;
  infected: boolean;
  signature?: string;
};

/**
 * Parses a clamd scan response. Shapes:
 *   "stream: OK"                          → clean
 *   "stream: Eicar-Test-Signature FOUND"  → infected
 *   "INSTREAM size limit exceeded. ERROR" → scanner error
 */
export function parseClamdResponse(raw: string): ClamdVerdict {
  const text = raw.replace(/\0/g, '').trim();
  if (/\bFOUND$/.test(text)) {
    const match = /:\s*(.+?)\s+FOUND$/.exec(text);
    return { ok: false, infected: true, signature: match?.[1] ?? 'unknown' };
  }
  if (/\bOK$/.test(text)) {
    return { ok: true, infected: false };
  }
  return { ok: false, infected: false };
}

/**
 * ClamAV (clamd) scanning over the INSTREAM TCP protocol — no SDK, files never
 * leave the compose network (student documents stay on our infrastructure).
 *
 * Enabled by setting CLAMAV_HOST (the docker-compose stack points it at the
 * `clamav` sidecar). When enabled the gate is FAIL-CLOSED: an unreachable or
 * erroring scanner rejects the upload with 503 rather than letting an
 * unscanned file through. When unset, scanning is skipped (dev/local mode) —
 * production logs a warning at boot, same pattern as the S3 fallback.
 */
@Injectable()
export class AntivirusService {
  private readonly logger = new Logger(AntivirusService.name);

  private readonly host = process.env.CLAMAV_HOST?.trim() ?? '';
  private readonly port = Number(process.env.CLAMAV_PORT ?? 3310);
  private readonly timeoutMs = Number(process.env.CLAMAV_TIMEOUT_MS ?? 30000);

  constructor() {
    if (this.isEnabled) {
      this.logger.log(`Antivirus: clamd at ${this.host}:${this.port}`);
    } else if (process.env.NODE_ENV === 'production') {
      this.logger.warn(
        'Antivirus: CLAMAV_HOST is not set — uploads are NOT scanned. ' +
          'Set CLAMAV_HOST (e.g. the clamav compose service) to enable scanning.',
      );
    }
  }

  get isEnabled(): boolean {
    return this.host.length > 0;
  }

  /**
   * Scans a buffer and returns normally when it is clean (or scanning is
   * disabled). Throws 422 for an infected file, 503 when the scanner is
   * configured but cannot deliver a verdict (fail-closed).
   */
  async assertClean(buffer: Buffer, label: string): Promise<void> {
    if (!this.isEnabled) return;

    let response: string;
    try {
      response = await this.instream(buffer);
    } catch (error) {
      this.logger.error(`ClamAV scan failed for ${label}: ${String(error)}`);
      throw new ServiceUnavailableException(
        'Antivirus scan unavailable. Please retry.',
      );
    }

    const verdict = parseClamdResponse(response);
    if (verdict.infected) {
      this.logger.warn(
        `ClamAV rejected ${label}: ${verdict.signature ?? 'unknown signature'}`,
      );
      throw new UnprocessableEntityException(
        'The file was rejected by the antivirus scan.',
      );
    }
    if (!verdict.ok) {
      this.logger.error(`ClamAV returned an error for ${label}: ${response.trim()}`);
      throw new ServiceUnavailableException(
        'Antivirus scan unavailable. Please retry.',
      );
    }
  }

  /**
   * clamd INSTREAM: `zINSTREAM\0`, then <4-byte BE length><data> chunks,
   * terminated by a zero-length chunk; the (z-style) response ends with \0.
   */
  private instream(buffer: Buffer): Promise<string> {
    return new Promise((resolvePromise, rejectPromise) => {
      const socket = new Socket();
      let response = '';
      let settled = false;

      const finish = (fn: () => void) => {
        if (settled) return;
        settled = true;
        fn();
        socket.destroy();
      };

      socket.setTimeout(this.timeoutMs, () =>
        finish(() => rejectPromise(new Error('clamd timed out'))),
      );
      socket.on('error', (error) => finish(() => rejectPromise(error)));
      socket.on('data', (chunk) => {
        response += chunk.toString();
        if (response.includes('\0')) {
          finish(() => resolvePromise(response));
        }
      });
      socket.on('close', () =>
        finish(() =>
          response
            ? resolvePromise(response)
            : rejectPromise(new Error('clamd closed without a response')),
        ),
      );

      socket.connect(this.port, this.host, () => {
        socket.write('zINSTREAM\0');
        const CHUNK = 64 * 1024;
        for (let offset = 0; offset < buffer.length; offset += CHUNK) {
          const slice = buffer.subarray(
            offset,
            Math.min(offset + CHUNK, buffer.length),
          );
          const size = Buffer.alloc(4);
          size.writeUInt32BE(slice.length, 0);
          socket.write(size);
          socket.write(slice);
        }
        socket.write(Buffer.alloc(4)); // zero-length chunk = end of stream
      });
    });
  }
}
