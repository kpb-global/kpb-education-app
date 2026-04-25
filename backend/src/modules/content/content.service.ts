import { Injectable, NotFoundException } from '@nestjs/common';

import { PublicationStatus } from '../../common/enums/publication-status.enum';
import { mockAdminData } from '../../common/data/mock-admin';
import { PrismaService } from '../prisma/prisma.service';

type ServiceOfferRecord = (typeof mockAdminData.serviceOffers)[number];
type SupportDestinationRecord = (typeof mockAdminData.supportDestinations)[number];
type ArticleRecord = (typeof mockAdminData.articles)[number];

@Injectable()
export class ContentService {
  constructor(private readonly prismaService: PrismaService) {}

  private readonly serviceOffers = [...mockAdminData.serviceOffers];
  private readonly supportDestinations = [...mockAdminData.supportDestinations];
  private readonly articles = [...mockAdminData.articles];

  async listServiceOffers() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.serviceOffer.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          name: { fr: item.nameFr, en: item.nameEn },
          offerType: item.offerType,
          destinationIds: item.destinationIds,
          studyLevels: item.studyLevels,
          priceLabel: { fr: item.priceLabelFr, en: item.priceLabelEn },
          benefits: { fr: item.benefitsFr, en: item.benefitsEn },
          ctaLabel: { fr: item.ctaLabelFr, en: item.ctaLabelEn },
          status: item.status,
        })),
      };
    }

    return { items: this.serviceOffers };
  }

  async createServiceOffer(input: Record<string, unknown>) {
    const record: ServiceOfferRecord = {
      id: `offer-${Date.now()}`,
      name:
        (input['name'] as ServiceOfferRecord['name'] | undefined) ??
        { fr: 'Nouvelle offre', en: 'New offer' },
      offerType: (input['offerType'] as string | undefined) ?? 'consultation',
      destinationIds:
        (input['destinationIds'] as string[] | undefined) ?? [],
      studyLevels: (input['studyLevels'] as string[] | undefined) ?? [],
      priceLabel:
        (input['priceLabel'] as ServiceOfferRecord['priceLabel'] | undefined) ??
        { fr: 'Sur devis', en: 'Quoted on request' },
      benefits:
        (input['benefits'] as ServiceOfferRecord['benefits'] | undefined) ??
        { fr: [], en: [] },
      ctaLabel:
        (input['ctaLabel'] as ServiceOfferRecord['ctaLabel'] | undefined) ??
        { fr: 'En savoir plus', en: 'Learn more' },
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
    };

    const created = await this.prismaService.execute((prisma) =>
      prisma.serviceOffer.create({
        data: {
          nameFr: record.name.fr,
          nameEn: record.name.en,
          offerType: record.offerType,
          destinationIds: record.destinationIds,
          studyLevels: record.studyLevels,
          priceLabelFr: record.priceLabel.fr,
          priceLabelEn: record.priceLabel.en,
          benefitsFr: record.benefits.fr,
          benefitsEn: record.benefits.en,
          ctaLabelFr: record.ctaLabel.fr,
          ctaLabelEn: record.ctaLabel.en,
          status: record.status,
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        name: { fr: created.nameFr, en: created.nameEn },
        offerType: created.offerType,
        destinationIds: created.destinationIds,
        studyLevels: created.studyLevels,
        priceLabel: { fr: created.priceLabelFr, en: created.priceLabelEn },
        benefits: { fr: created.benefitsFr, en: created.benefitsEn },
        ctaLabel: { fr: created.ctaLabelFr, en: created.ctaLabelEn },
        status: created.status,
      };
    }

    this.serviceOffers.unshift(record);
    return record;
  }

  async updateServiceOffer(id: string, input: Record<string, unknown>) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.serviceOffer.update({
        where: { id },
        data: {
          ...(input['name']
            ? {
                nameFr: (input['name'] as ServiceOfferRecord['name']).fr,
                nameEn: (input['name'] as ServiceOfferRecord['name']).en,
              }
            : {}),
          ...(input['offerType']
            ? { offerType: input['offerType'] as string }
            : {}),
          ...(input['destinationIds']
            ? { destinationIds: input['destinationIds'] as string[] }
            : {}),
          ...(input['studyLevels']
            ? { studyLevels: input['studyLevels'] as string[] }
            : {}),
          ...(input['priceLabel']
            ? {
                priceLabelFr: (input['priceLabel'] as ServiceOfferRecord['priceLabel']).fr,
                priceLabelEn: (input['priceLabel'] as ServiceOfferRecord['priceLabel']).en,
              }
            : {}),
          ...(input['benefits']
            ? {
                benefitsFr: (input['benefits'] as ServiceOfferRecord['benefits']).fr,
                benefitsEn: (input['benefits'] as ServiceOfferRecord['benefits']).en,
              }
            : {}),
          ...(input['ctaLabel']
            ? {
                ctaLabelFr: (input['ctaLabel'] as ServiceOfferRecord['ctaLabel']).fr,
                ctaLabelEn: (input['ctaLabel'] as ServiceOfferRecord['ctaLabel']).en,
              }
            : {}),
          ...(input['status']
            ? { status: input['status'] as PublicationStatus }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        name: { fr: updated.nameFr, en: updated.nameEn },
        offerType: updated.offerType,
        destinationIds: updated.destinationIds,
        studyLevels: updated.studyLevels,
        priceLabel: { fr: updated.priceLabelFr, en: updated.priceLabelEn },
        benefits: { fr: updated.benefitsFr, en: updated.benefitsEn },
        ctaLabel: { fr: updated.ctaLabelFr, en: updated.ctaLabelEn },
        status: updated.status,
      };
    }

    const index = this.serviceOffers.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Service offer ${id} not found.`);
    }
    this.serviceOffers[index] = {
      ...this.serviceOffers[index],
      ...input,
    } as ServiceOfferRecord;
    return this.serviceOffers[index];
  }

  async listSupportDestinations() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.supportDestination.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          countryId: item.countryId,
          countryName: { fr: item.countryNameFr, en: item.countryNameEn },
          supportLanguages: item.supportLanguages,
          availableServiceTypes: item.availableServiceTypes,
          conditions: { fr: item.conditionsFr, en: item.conditionsEn },
          counselorNames: item.counselorNames,
          isVisible: item.isVisible,
          status: item.status,
        })),
      };
    }

    return { items: this.supportDestinations };
  }

  async createSupportDestination(input: Record<string, unknown>) {
    const record: SupportDestinationRecord = {
      id: `support-${Date.now()}`,
      countryId: (input['countryId'] as string | undefined) ?? 'new-country',
      countryName:
        (input['countryName'] as SupportDestinationRecord['countryName'] | undefined) ??
        { fr: 'Nouveau pays', en: 'New country' },
      supportLanguages:
        (input['supportLanguages'] as string[] | undefined) ?? ['fr'],
      availableServiceTypes:
        (input['availableServiceTypes'] as string[] | undefined) ??
        ['consultation'],
      conditions:
        (input['conditions'] as SupportDestinationRecord['conditions'] | undefined) ??
        { fr: [], en: [] },
      counselorNames:
        (input['counselorNames'] as string[] | undefined) ?? [],
      isVisible: (input['isVisible'] as boolean | undefined) ?? true,
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
    };

    const created = await this.prismaService.execute((prisma) =>
      prisma.supportDestination.create({
        data: {
          countryId: record.countryId,
          countryNameFr: record.countryName.fr,
          countryNameEn: record.countryName.en,
          supportLanguages: record.supportLanguages,
          availableServiceTypes: record.availableServiceTypes,
          conditionsFr: record.conditions.fr,
          conditionsEn: record.conditions.en,
          counselorNames: record.counselorNames,
          isVisible: record.isVisible,
          status: record.status,
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        countryId: created.countryId,
        countryName: { fr: created.countryNameFr, en: created.countryNameEn },
        supportLanguages: created.supportLanguages,
        availableServiceTypes: created.availableServiceTypes,
        conditions: { fr: created.conditionsFr, en: created.conditionsEn },
        counselorNames: created.counselorNames,
        isVisible: created.isVisible,
        status: created.status,
      };
    }

    this.supportDestinations.unshift(record);
    return record;
  }

  async updateSupportDestination(id: string, input: Record<string, unknown>) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.supportDestination.update({
        where: { id },
        data: {
          ...(input['countryId']
            ? { countryId: input['countryId'] as string }
            : {}),
          ...(input['countryName']
            ? {
                countryNameFr:
                  (input['countryName'] as SupportDestinationRecord['countryName']).fr,
                countryNameEn:
                  (input['countryName'] as SupportDestinationRecord['countryName']).en,
              }
            : {}),
          ...(input['supportLanguages']
            ? { supportLanguages: input['supportLanguages'] as string[] }
            : {}),
          ...(input['availableServiceTypes']
            ? {
                availableServiceTypes:
                  input['availableServiceTypes'] as string[],
              }
            : {}),
          ...(input['conditions']
            ? {
                conditionsFr:
                  (input['conditions'] as SupportDestinationRecord['conditions']).fr,
                conditionsEn:
                  (input['conditions'] as SupportDestinationRecord['conditions']).en,
              }
            : {}),
          ...(input['counselorNames']
            ? { counselorNames: input['counselorNames'] as string[] }
            : {}),
          ...(input['isVisible'] !== undefined
            ? { isVisible: input['isVisible'] as boolean }
            : {}),
          ...(input['status']
            ? { status: input['status'] as PublicationStatus }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        countryId: updated.countryId,
        countryName: { fr: updated.countryNameFr, en: updated.countryNameEn },
        supportLanguages: updated.supportLanguages,
        availableServiceTypes: updated.availableServiceTypes,
        conditions: { fr: updated.conditionsFr, en: updated.conditionsEn },
        counselorNames: updated.counselorNames,
        isVisible: updated.isVisible,
        status: updated.status,
      };
    }

    const index = this.supportDestinations.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Support destination ${id} not found.`);
    }
    this.supportDestinations[index] = {
      ...this.supportDestinations[index],
      ...input,
    } as SupportDestinationRecord;
    return this.supportDestinations[index];
  }

  async listArticles() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.article.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          slug: item.slug,
          category: item.category,
          title: { fr: item.titleFr, en: item.titleEn },
          summary: { fr: item.summaryFr, en: item.summaryEn },
          content: { fr: item.contentFr, en: item.contentEn },
          tags: item.tags,
          authorName: item.authorName,
          status: item.status,
          publishedAt: item.publishedAt?.toISOString() ?? null,
        })),
      };
    }

    return { items: this.articles };
  }

  async createArticle(input: Record<string, unknown>) {
    const record: ArticleRecord = {
      id: `article-${Date.now()}`,
      slug: (input['slug'] as string | undefined) ?? `article-${Date.now()}`,
      category: (input['category'] as string | undefined) ?? 'guides',
      title:
        (input['title'] as ArticleRecord['title'] | undefined) ??
        { fr: 'Nouvel article', en: 'New article' },
      summary:
        (input['summary'] as ArticleRecord['summary'] | undefined) ??
        { fr: '', en: '' },
      content:
        (input['content'] as ArticleRecord['content'] | undefined) ??
        { fr: '', en: '' },
      tags: (input['tags'] as string[] | undefined) ?? [],
      authorName: (input['authorName'] as string | undefined) ?? 'KPB Editorial',
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
      publishedAt: (input['publishedAt'] as string | null | undefined) ?? null,
    };

    const created = await this.prismaService.execute((prisma) =>
      prisma.article.create({
        data: {
          slug: record.slug,
          category: record.category,
          titleFr: record.title.fr,
          titleEn: record.title.en,
          summaryFr: record.summary.fr,
          summaryEn: record.summary.en,
          contentFr: record.content.fr,
          contentEn: record.content.en,
          tags: record.tags,
          authorName: record.authorName,
          status: record.status,
          publishedAt: record.publishedAt ? new Date(record.publishedAt) : null,
        },
      }),
    );

    if (created) {
      return {
        id: created.id,
        slug: created.slug,
        category: created.category,
        title: { fr: created.titleFr, en: created.titleEn },
        summary: { fr: created.summaryFr, en: created.summaryEn },
        content: { fr: created.contentFr, en: created.contentEn },
        tags: created.tags,
        authorName: created.authorName,
        status: created.status,
        publishedAt: created.publishedAt?.toISOString() ?? null,
      };
    }

    this.articles.unshift(record);
    return record;
  }

  async updateArticle(id: string, input: Record<string, unknown>) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.article.update({
        where: { id },
        data: {
          ...(input['slug'] ? { slug: input['slug'] as string } : {}),
          ...(input['category']
            ? { category: input['category'] as string }
            : {}),
          ...(input['title']
            ? {
                titleFr: (input['title'] as ArticleRecord['title']).fr,
                titleEn: (input['title'] as ArticleRecord['title']).en,
              }
            : {}),
          ...(input['summary']
            ? {
                summaryFr: (input['summary'] as ArticleRecord['summary']).fr,
                summaryEn: (input['summary'] as ArticleRecord['summary']).en,
              }
            : {}),
          ...(input['content']
            ? {
                contentFr: (input['content'] as ArticleRecord['content']).fr,
                contentEn: (input['content'] as ArticleRecord['content']).en,
              }
            : {}),
          ...(input['tags'] ? { tags: input['tags'] as string[] } : {}),
          ...(input['authorName']
            ? { authorName: input['authorName'] as string }
            : {}),
          ...(input['status']
            ? { status: input['status'] as PublicationStatus }
            : {}),
          ...(input['publishedAt'] !== undefined
            ? {
                publishedAt: input['publishedAt']
                  ? new Date(input['publishedAt'] as string)
                  : null,
              }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        slug: updated.slug,
        category: updated.category,
        title: { fr: updated.titleFr, en: updated.titleEn },
        summary: { fr: updated.summaryFr, en: updated.summaryEn },
        content: { fr: updated.contentFr, en: updated.contentEn },
        tags: updated.tags,
        authorName: updated.authorName,
        status: updated.status,
        publishedAt: updated.publishedAt?.toISOString() ?? null,
      };
    }

    const index = this.articles.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Article ${id} not found.`);
    }
    this.articles[index] = {
      ...this.articles[index],
      ...input,
    } as ArticleRecord;
    return this.articles[index];
  }
}
