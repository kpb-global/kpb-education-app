import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Socket } from 'net';

/**
 * The scanner delivered a verdict and it was positive: the FILE is the problem.
 * Subclasses the exception this path has always thrown (422), so existing
 * `instanceof UnprocessableEntityException` consumers are unaffected — callers
 * that need to tell "infected" from "no verdict" now can.
 */
export class InfectedFileError extends UnprocessableEntityException {}

/**
 * Fail-closed outcome: the scanner is configured but produced no usable verdict
 * (unreachable, timed out, ERROR response). Not the user's fault — retrying
 * later is the honest advice. Subclasses the 503 previously thrown here.
 */
export class AntivirusUnavailableError extends ServiceUnavailableException {}

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
/**
 * Fichier de test EICAR, assemblé à l'exécution.
 *
 * Jamais écrit d'un seul tenant : une chaîne EICAR contiguë dans un fichier
 * source fait réagir les antivirus des postes de développement et des chaînes
 * d'intégration. Le fragmenter n'est pas de la dissimulation — c'est la
 * pratique habituelle pour un motif conçu pour être détecté.
 */
function eicarProbe(): Buffer {
  const parts = [
    'X5O!P%@AP[4\\PZX54(P^)7CC)7}',
    '$EICAR-STANDARD-ANTIVIRUS-',
    'TEST-FILE!$H+H*',
  ];
  return Buffer.from(parts.join(''), 'ascii');
}

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
  async assertClean(buffer: Buffer, _label: string): Promise<void> {
    if (!this.isEnabled) return;

    let response: string;
    try {
      response = await this.instream(buffer);
    } catch {
      // The original user-provided filename must never reach logs.
      this.logger.error('ClamAV scan request failed.');
      throw new AntivirusUnavailableError(
        'Antivirus scan unavailable. Please retry.',
      );
    }

    const verdict = parseClamdResponse(response);
    if (verdict.infected) {
      this.logger.warn('ClamAV rejected an uploaded private object.');
      throw new InfectedFileError(
        'The file was rejected by the antivirus scan.',
      );
    }
    if (!verdict.ok) {
      this.logger.error('ClamAV returned an invalid or error verdict.');
      throw new AntivirusUnavailableError(
        'Antivirus scan unavailable. Please retry.',
      );
    }
  }

  /**
   * L'analyse fonctionne-t-elle VRAIMENT, maintenant ?
   *
   * Distinct de `isEnabled`, qui ne dit que « une adresse est configurée ».
   * Toute la panne du 15/08/2026 tient dans cet écart : `CLAMAV_HOST` est
   * resté valide pendant vingt jours pendant que clamd était mort, et
   * `AntivirusService` étant FAIL-CLOSED, chaque envoi repartait en 503 sans
   * que rien ne le signale. Le conteneur restait « Up » parce que
   * `freshclam`, lui, tournait — il mettait à jour les signatures d'un daemon
   * absent, tous les matins, pendant vingt jours.
   *
   * On envoie le fichier de test EICAR par `assertClean` — donc EXACTEMENT le
   * chemin qu'empruntent les envois réels. Un simple PING aurait été plus
   * simple et plus faible : il ne prouve que le canal de contrôle. Un clamd
   * qui répond PONG peut très bien refuser INSTREAM (limite de taille) ou
   * tourner sans base chargée, et rendre 503 sur chaque fichier — soit
   * précisément la panne qu'on prétend détecter.
   *
   * Trois issues, trois significations :
   *   - `InfectedFileError`        → le scanner a rendu un VERDICT correct ✅
   *   - retour sans exception      → EICAR déclaré propre : rien n'est détecté
   *   - `AntivirusUnavailableError`→ pas de verdict du tout
   *
   * Ne LÈVE JAMAIS : cette méthode sert une route de santé, et une sonde qui
   * échoue est un résultat, pas une panne de la route.
   */
  async selfTest(): Promise<boolean> {
    if (!this.isEnabled) return false;
    try {
      await this.assertClean(eicarProbe(), 'antivirus-selftest');
      // EICAR déclaré propre : le daemon répond mais ne détecte rien — base
      // non chargée, ou en cours de rechargement. Un fichier réellement
      // infecté passerait. Ce n'est pas « sain ».
      this.logger.error(
        'Antivirus self-test: EICAR was reported CLEAN — signatures are not loaded.',
      );
      return false;
    } catch (error) {
      return error instanceof InfectedFileError;
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
