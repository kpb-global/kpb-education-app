import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';

@Injectable()
export class MagicLinkMailService {
  private readonly logger = new Logger(MagicLinkMailService.name);

  async sendMagicLink(
    email: string,
    payload: { token: string; code: string },
  ): Promise<void> {
    const appLink = `kpb://auth/verify?token=${encodeURIComponent(payload.token)}`;
    const webBase = process.env.KPB_MAGIC_LINK_WEB_BASE?.trim();
    const webLink = webBase
      ? `${webBase.replace(/\/$/, '')}/auth/verify?token=${encodeURIComponent(payload.token)}`
      : null;

    const body = [
      'Bonjour,',
      '',
      'Voici votre code de connexion KPB Education :',
      '',
      `  ${payload.code}`,
      '',
      'Ou ouvrez ce lien dans l’application :',
      appLink,
      ...(webLink ? ['', 'Lien web :', webLink] : []),
      '',
      'Ce code expire dans 15 minutes.',
      '',
      '— KPB Education',
    ].join('\n');

    const resendKey = process.env.RESEND_API_KEY?.trim();
    if (resendKey) {
      const from =
        process.env.KPB_MAGIC_LINK_FROM?.trim() ?? 'KPB Education <noreply@kpbeducation.cloud>';
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [email],
          subject: 'Votre code de connexion KPB Education',
          text: body,
        }),
      });
      if (!response.ok) {
        const detail = await response.text();
        this.logger.error(`Resend failed (${response.status}): ${detail}`);
        throw new Error('Email delivery failed.');
      }
      return;
    }

    // No email provider configured. In production this must fail loudly rather
    // than silently pretend the link was sent — and we must NEVER write the
    // one-time code/token to the logs (they are login secrets).
    if (process.env.NODE_ENV === 'production') {
      this.logger.error(
        `Cannot send magic link to ${email}: RESEND_API_KEY is not configured.`,
      );
      throw new ServiceUnavailableException(
        'Email delivery is not configured.',
      );
    }

    this.logger.log(
      `[dev] Magic link for ${email}\n  code=${payload.code}\n  token=${payload.token}\n  link=${appLink}`,
    );
  }
}
