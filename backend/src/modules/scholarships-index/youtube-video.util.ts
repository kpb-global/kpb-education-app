import { BadRequestException } from '@nestjs/common';

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;
const YOUTUBE_HOSTS = new Set([
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtu.be',
  'www.youtu.be',
]);

export function extractYoutubeVideoId(rawUrl: string): string {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new BadRequestException('youtubeUrl must be a valid URL.');
  }
  if (url.protocol !== 'https:' || !YOUTUBE_HOSTS.has(url.hostname)) {
    throw new BadRequestException(
      'youtubeUrl must be an HTTPS youtube.com or youtu.be URL.',
    );
  }

  let candidate: string | null = null;
  if (url.hostname.endsWith('youtu.be')) {
    candidate = url.pathname.split('/').filter(Boolean)[0] ?? null;
  } else if (url.pathname === '/watch') {
    candidate = url.searchParams.get('v');
  } else {
    const segments = url.pathname.split('/').filter(Boolean);
    if (['embed', 'shorts', 'live'].includes(segments[0] ?? '')) {
      candidate = segments[1] ?? null;
    }
  }

  if (!candidate || !YOUTUBE_ID.test(candidate)) {
    throw new BadRequestException(
      'youtubeUrl does not contain a valid 11-character YouTube video id.',
    );
  }
  return candidate;
}

export function youtubeVideoUrls(youtubeVideoId: string) {
  return {
    watchUrl: `https://www.youtube.com/watch?v=${youtubeVideoId}`,
    shareUrl: `https://youtu.be/${youtubeVideoId}`,
  };
}
