import {
  ConflictException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Prisma, ScholarshipVideo } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CreateScholarshipVideoDto } from './dto/create-scholarship-video.dto';
import { UpdateScholarshipVideoDto } from './dto/update-scholarship-video.dto';
import {
  extractYoutubeVideoId,
  youtubeVideoUrls,
} from './youtube-video.util';

@Injectable()
export class ScholarshipVideosService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async list(scholarshipId: string) {
    this.assertDb();
    const exists = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findUnique({
        where: { id: scholarshipId },
        select: { id: true },
      }),
    );
    if (!exists) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    const videos = await this.prismaService.execute((prisma) =>
      prisma.scholarshipVideo.findMany({
        where: { scholarshipId },
        orderBy: [{ isFeatured: 'desc' }, { displayOrder: 'asc' }],
      }),
    );
    return { items: (videos ?? []).map((video) => this.adminDto(video)) };
  }

  async create(scholarshipId: string, input: CreateScholarshipVideoDto) {
    this.assertDb();
    const youtubeVideoId = extractYoutubeVideoId(input.youtubeUrl);
    try {
      const video = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const scholarship = await tx.scholarship.findUnique({
            where: { id: scholarshipId },
            select: { id: true },
          });
          if (!scholarship) return null;
          if (input.isFeatured) {
            await tx.scholarshipVideo.updateMany({
              where: { scholarshipId, isFeatured: true },
              data: { isFeatured: false },
            });
          }
          return tx.scholarshipVideo.create({
            data: {
              scholarshipId,
              youtubeVideoId,
              titleFr: input.titleFr.trim(),
              titleEn: input.titleEn.trim(),
              descriptionFr: input.descriptionFr?.trim() ?? '',
              descriptionEn: input.descriptionEn?.trim() ?? '',
              thumbnailUrl:
                input.thumbnailUrl ??
                `https://img.youtube.com/vi/${youtubeVideoId}/hqdefault.jpg`,
              durationSeconds: input.durationSeconds,
              languageCode: input.languageCode ?? 'fr',
              youtubePublishedAt: input.youtubePublishedAt
                ? new Date(input.youtubePublishedAt)
                : null,
              status: input.status ?? 'draft',
              isFeatured: input.isFeatured ?? false,
              displayOrder: input.displayOrder ?? 0,
            },
          });
        }),
      );
      if (!video) {
        throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
      }
      return this.adminDto(video);
    } catch (error) {
      this.rethrowDuplicate(error);
    }
  }

  async update(
    scholarshipId: string,
    videoId: string,
    input: UpdateScholarshipVideoDto,
  ) {
    this.assertDb();
    const data: Prisma.ScholarshipVideoUpdateInput = {
      ...(input.youtubeUrl
        ? { youtubeVideoId: extractYoutubeVideoId(input.youtubeUrl) }
        : {}),
      ...(input.titleFr !== undefined ? { titleFr: input.titleFr.trim() } : {}),
      ...(input.titleEn !== undefined ? { titleEn: input.titleEn.trim() } : {}),
      ...(input.descriptionFr !== undefined
        ? { descriptionFr: input.descriptionFr.trim() }
        : {}),
      ...(input.descriptionEn !== undefined
        ? { descriptionEn: input.descriptionEn.trim() }
        : {}),
      ...(input.thumbnailUrl !== undefined
        ? { thumbnailUrl: input.thumbnailUrl }
        : {}),
      ...(input.durationSeconds !== undefined
        ? { durationSeconds: input.durationSeconds }
        : {}),
      ...(input.languageCode !== undefined
        ? { languageCode: input.languageCode }
        : {}),
      ...(input.youtubePublishedAt !== undefined
        ? { youtubePublishedAt: new Date(input.youtubePublishedAt) }
        : {}),
      ...(input.status !== undefined ? { status: input.status } : {}),
      ...(input.isFeatured !== undefined
        ? { isFeatured: input.isFeatured }
        : {}),
      ...(input.displayOrder !== undefined
        ? { displayOrder: input.displayOrder }
        : {}),
    };

    try {
      const video = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const existing = await tx.scholarshipVideo.findFirst({
            where: { id: videoId, scholarshipId },
            select: { id: true },
          });
          if (!existing) return null;
          if (input.isFeatured) {
            await tx.scholarshipVideo.updateMany({
              where: { scholarshipId, isFeatured: true, id: { not: videoId } },
              data: { isFeatured: false },
            });
          }
          return tx.scholarshipVideo.update({
            where: { id: videoId },
            data,
          });
        }),
      );
      if (!video) {
        throw new NotFoundException(
          `Video ${videoId} not found for scholarship ${scholarshipId}.`,
        );
      }
      return this.adminDto(video);
    } catch (error) {
      this.rethrowDuplicate(error);
    }
  }

  async delete(scholarshipId: string, videoId: string) {
    this.assertDb();
    const result = await this.prismaService.execute((prisma) =>
      prisma.scholarshipVideo.deleteMany({
        where: { id: videoId, scholarshipId },
      }),
    );
    if (!result?.count) {
      throw new NotFoundException(
        `Video ${videoId} not found for scholarship ${scholarshipId}.`,
      );
    }
    return { id: videoId, deleted: true };
  }

  private adminDto(video: ScholarshipVideo) {
    return {
      ...video,
      ...youtubeVideoUrls(video.youtubeVideoId),
    };
  }

  private rethrowDuplicate(error: unknown): never {
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code: string }).code === 'P2002'
    ) {
      throw new ConflictException(
        'This YouTube video is already attached to the scholarship.',
      );
    }
    throw error;
  }
}
