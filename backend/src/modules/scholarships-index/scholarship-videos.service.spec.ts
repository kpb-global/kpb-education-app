import { PrismaService } from '../prisma/prisma.service';
import { ScholarshipVideosService } from './scholarship-videos.service';

describe('ScholarshipVideosService', () => {
  it('stores a parsed YouTube id and returns canonical URLs', async () => {
    let createdData: Record<string, unknown> = {};
    type Client = {
      $transaction: (fn: (tx: Client) => unknown) => Promise<unknown>;
      scholarship: { findUnique: () => Promise<{ id: string }> };
      scholarshipVideo: {
        updateMany: () => Promise<{ count: number }>;
        create: (input: {
          data: Record<string, unknown>;
        }) => Promise<Record<string, unknown>>;
      };
    };
    const client: Client = {
      $transaction: async (fn) => fn(client),
      scholarship: {
        findUnique: async () => ({ id: 'sch-1' }),
      },
      scholarshipVideo: {
        updateMany: async () => ({ count: 1 }),
        create: async ({ data }: { data: Record<string, unknown> }) => {
          createdData = data;
          return {
            id: 'video-1',
            scholarshipId: 'sch-1',
            youtubeVideoId: data.youtubeVideoId as string,
            titleFr: data.titleFr as string,
            titleEn: data.titleEn as string,
            descriptionFr: '',
            descriptionEn: '',
            thumbnailUrl: data.thumbnailUrl as string,
            durationSeconds: null,
            languageCode: 'fr',
            youtubePublishedAt: null,
            status: 'published' as const,
            isFeatured: true,
            displayOrder: 0,
            createdAt: new Date(),
            updatedAt: new Date(),
          };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (value: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ScholarshipVideosService(prisma);

    const result = await service.create('sch-1', {
      youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
      titleFr: ' Comment postuler ',
      titleEn: ' How to apply ',
      status: 'published',
      isFeatured: true,
    });

    expect(createdData).toMatchObject({
      youtubeVideoId: 'dQw4w9WgXcQ',
      titleFr: 'Comment postuler',
      titleEn: 'How to apply',
      isFeatured: true,
    });
    expect(result).toMatchObject({
      youtubeVideoId: 'dQw4w9WgXcQ',
      watchUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      shareUrl: 'https://youtu.be/dQw4w9WgXcQ',
    });
  });

  it('scopes deletion to both scholarship and video identifiers', async () => {
    const deleteMany = jest.fn().mockResolvedValue({ count: 1 });
    const client = { scholarshipVideo: { deleteMany } };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (value: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ScholarshipVideosService(prisma);

    await expect(service.delete('sch-1', 'video-1')).resolves.toEqual({
      id: 'video-1',
      deleted: true,
    });
    expect(deleteMany).toHaveBeenCalledWith({
      where: { id: 'video-1', scholarshipId: 'sch-1' },
    });
  });
});
