import { BadRequestException } from '@nestjs/common';

import {
  extractYoutubeVideoId,
  youtubeVideoUrls,
} from './youtube-video.util';

describe('YouTube video URL utilities', () => {
  const id = 'dQw4w9WgXcQ';

  it.each([
    `https://www.youtube.com/watch?v=${id}`,
    `https://youtu.be/${id}`,
    `https://www.youtube.com/shorts/${id}`,
    `https://www.youtube.com/embed/${id}`,
    `https://www.youtube.com/live/${id}`,
  ])('extracts the stable id from %s', (url) => {
    expect(extractYoutubeVideoId(url)).toBe(id);
  });

  it('rejects non-YouTube and non-HTTPS URLs', () => {
    expect(() => extractYoutubeVideoId(`https://example.org/${id}`)).toThrow(
      BadRequestException,
    );
    expect(() =>
      extractYoutubeVideoId(`http://www.youtube.com/watch?v=${id}`),
    ).toThrow(BadRequestException);
  });

  it('builds canonical watch and share URLs', () => {
    expect(youtubeVideoUrls(id)).toEqual({
      watchUrl: `https://www.youtube.com/watch?v=${id}`,
      shareUrl: `https://youtu.be/${id}`,
    });
  });
});
