'use client';

import { FormEvent, useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { apiFetch } from '../../lib/api-client';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  splitList,
  textareaStyle,
} from '../../lib/ui';

interface ServiceOfferItem {
  id: string;
  name: { fr: string; en: string };
  offerType: string;
  destinationIds: string[];
  studyLevels: string[];
  priceLabel: { fr: string; en: string };
  status: string;
}

interface SupportDestinationItem {
  id: string;
  countryName: { fr: string; en: string };
  supportLanguages: string[];
  availableServiceTypes: string[];
  counselorNames: string[];
  isVisible: boolean;
  status: string;
}

interface ArticleItem {
  id: string;
  title: { fr: string; en: string };
  category: string;
  authorName: string;
  status: string;
}

export default function ContentPage() {
  const [serviceOffers, setServiceOffers] = useState<ServiceOfferItem[]>([]);
  const [supportDestinations, setSupportDestinations] = useState<
    SupportDestinationItem[]
  >([]);
  const [articles, setArticles] = useState<ArticleItem[]>([]);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [offerForm, setOfferForm] = useState({
    nameFr: '',
    nameEn: '',
    offerType: 'consultation',
    destinationIds: '',
    studyLevels: '',
    priceFr: 'Sur devis',
    priceEn: 'Quoted on request',
    benefitsFr: '',
    benefitsEn: '',
    ctaFr: 'En savoir plus',
    ctaEn: 'Learn more',
    status: 'draft',
  });
  const [destinationForm, setDestinationForm] = useState({
    countryId: '',
    countryFr: '',
    countryEn: '',
    supportLanguages: 'fr,en',
    serviceTypes: 'consultation',
    conditionsFr: '',
    conditionsEn: '',
    counselors: '',
    isVisible: true,
    status: 'draft',
  });
  const [articleForm, setArticleForm] = useState({
    slug: '',
    category: 'guides',
    titleFr: '',
    titleEn: '',
    summaryFr: '',
    summaryEn: '',
    contentFr: '',
    contentEn: '',
    tags: '',
    authorName: 'KPB Editorial',
    status: 'draft',
  });

  async function loadContent() {
    setErrorMessage(null);
    try {
      const [offersResponse, destinationsResponse, articlesResponse] =
        await Promise.all([
          apiFetch<{ items: ServiceOfferItem[] }>('/admin/service-offers'),
          apiFetch<{ items: SupportDestinationItem[] }>(
            '/admin/support-destinations',
          ),
          apiFetch<{ items: ArticleItem[] }>('/admin/articles'),
        ]);
      setServiceOffers(offersResponse.items);
      setSupportDestinations(destinationsResponse.items);
      setArticles(articlesResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load content.',
      );
    }
  }

  useEffect(() => {
    void loadContent();
  }, []);

  async function submitOffer(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      await apiFetch('/admin/service-offers', {
        method: 'POST',
        body: {
          name: { fr: offerForm.nameFr, en: offerForm.nameEn },
          offerType: offerForm.offerType,
          destinationIds: splitList(offerForm.destinationIds),
          studyLevels: splitList(offerForm.studyLevels),
          priceLabel: { fr: offerForm.priceFr, en: offerForm.priceEn },
          benefits: {
            fr: offerForm.benefitsFr
              .split('\n')
              .map((item) => item.trim())
              .filter(Boolean),
            en: offerForm.benefitsEn
              .split('\n')
              .map((item) => item.trim())
              .filter(Boolean),
          },
          ctaLabel: { fr: offerForm.ctaFr, en: offerForm.ctaEn },
          status: offerForm.status,
        },
      });
      setOfferForm({
        nameFr: '',
        nameEn: '',
        offerType: 'consultation',
        destinationIds: '',
        studyLevels: '',
        priceFr: 'Sur devis',
        priceEn: 'Quoted on request',
        benefitsFr: '',
        benefitsEn: '',
        ctaFr: 'En savoir plus',
        ctaEn: 'Learn more',
        status: 'draft',
      });
      setStatusMessage('Service offer published to the operations catalog.');
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create offer.',
      );
    }
  }

  async function submitDestination(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      await apiFetch('/admin/support-destinations', {
        method: 'POST',
        body: {
          countryId: destinationForm.countryId,
          countryName: {
            fr: destinationForm.countryFr,
            en: destinationForm.countryEn,
          },
          supportLanguages: splitList(destinationForm.supportLanguages),
          availableServiceTypes: splitList(destinationForm.serviceTypes),
          conditions: {
            fr: destinationForm.conditionsFr
              .split('\n')
              .map((item) => item.trim())
              .filter(Boolean),
            en: destinationForm.conditionsEn
              .split('\n')
              .map((item) => item.trim())
              .filter(Boolean),
          },
          counselorNames: splitList(destinationForm.counselors),
          isVisible: destinationForm.isVisible,
          status: destinationForm.status,
        },
      });
      setDestinationForm({
        countryId: '',
        countryFr: '',
        countryEn: '',
        supportLanguages: 'fr,en',
        serviceTypes: 'consultation',
        conditionsFr: '',
        conditionsEn: '',
        counselors: '',
        isVisible: true,
        status: 'draft',
      });
      setStatusMessage('Support destination added successfully.');
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to create support destination.',
      );
    }
  }

  async function submitArticle(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      await apiFetch('/admin/articles', {
        method: 'POST',
        body: {
          slug: articleForm.slug,
          category: articleForm.category,
          title: { fr: articleForm.titleFr, en: articleForm.titleEn },
          summary: { fr: articleForm.summaryFr, en: articleForm.summaryEn },
          content: { fr: articleForm.contentFr, en: articleForm.contentEn },
          tags: splitList(articleForm.tags),
          authorName: articleForm.authorName,
          status: articleForm.status,
          publishedAt:
            articleForm.status === 'published'
              ? new Date().toISOString()
              : null,
        },
      });
      setArticleForm({
        slug: '',
        category: 'guides',
        titleFr: '',
        titleEn: '',
        summaryFr: '',
        summaryEn: '',
        contentFr: '',
        contentEn: '',
        tags: '',
        authorName: 'KPB Editorial',
        status: 'draft',
      });
      setStatusMessage('Article added to the editorial queue.');
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create article.',
      );
    }
  }

  return (
    <DashboardShell title="Content">
      <div style={{ display: 'grid', gap: 18 }}>
        {statusMessage ? (
          <div style={{ ...panelStyle, background: '#ECFDF5', color: '#166534' }}>
            {statusMessage}
          </div>
        ) : null}
        {errorMessage ? (
          <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
            {errorMessage}
          </div>
        ) : null}

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>Service offers</h3>
            <p style={mutedTextStyle}>
              Add a new KPB premium or consultative offer that can surface in the
              mobile app.
            </p>
          </div>
          <form
            onSubmit={submitOffer}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
            <label style={labelStyle}>
              Offer name (FR)
              <input
                value={offerForm.nameFr}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    nameFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Offer name (EN)
              <input
                value={offerForm.nameEn}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    nameEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Offer type
              <input
                value={offerForm.offerType}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    offerType: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Status
              <select
                value={offerForm.status}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    status: event.target.value,
                  }))
                }
                style={inputStyle}
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
                <option value="archived">Archived</option>
              </select>
            </label>
            <label style={labelStyle}>
              Destination IDs
              <input
                value={offerForm.destinationIds}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    destinationIds: event.target.value,
                  }))
                }
                placeholder="canada,france,germany"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Study levels
              <input
                value={offerForm.studyLevels}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    studyLevels: event.target.value,
                  }))
                }
                placeholder="high_school,bachelor,master"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Price label (FR)
              <input
                value={offerForm.priceFr}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    priceFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Price label (EN)
              <input
                value={offerForm.priceEn}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    priceEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Benefits (FR, one per line)
              <textarea
                value={offerForm.benefitsFr}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    benefitsFr: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Benefits (EN, one per line)
              <textarea
                value={offerForm.benefitsEn}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    benefitsEn: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={labelStyle}>
              CTA (FR)
              <input
                value={offerForm.ctaFr}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    ctaFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              CTA (EN)
              <input
                value={offerForm.ctaEn}
                onChange={(event) =>
                  setOfferForm((current) => ({
                    ...current,
                    ctaEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <button type="submit" style={{ ...buttonStyle, gridColumn: '1 / -1' }}>
              Add service offer
            </button>
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {serviceOffers.map((offer) => (
              <div key={offer.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                <strong>{offer.name.fr}</strong>
                <p style={{ margin: '6px 0' }}>
                  {offer.offerType} • {offer.destinationIds.join(', ') || 'global'}
                </p>
                <span style={badgeStyle}>{offer.status}</span>
              </div>
            ))}
          </div>
        </section>

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>Support destinations</h3>
            <p style={mutedTextStyle}>
              Control which accompaniment countries appear in the mobile explore
              experience.
            </p>
          </div>
          <form
            onSubmit={submitDestination}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
            <label style={labelStyle}>
              Country ID
              <input
                value={destinationForm.countryId}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    countryId: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Status
              <select
                value={destinationForm.status}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    status: event.target.value,
                  }))
                }
                style={inputStyle}
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
                <option value="archived">Archived</option>
              </select>
            </label>
            <label style={labelStyle}>
              Country name (FR)
              <input
                value={destinationForm.countryFr}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    countryFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Country name (EN)
              <input
                value={destinationForm.countryEn}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    countryEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Support languages
              <input
                value={destinationForm.supportLanguages}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    supportLanguages: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Service types
              <input
                value={destinationForm.serviceTypes}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    serviceTypes: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Conditions (FR, one per line)
              <textarea
                value={destinationForm.conditionsFr}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    conditionsFr: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Conditions (EN, one per line)
              <textarea
                value={destinationForm.conditionsEn}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    conditionsEn: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={labelStyle}>
              Counselors
              <input
                value={destinationForm.counselors}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    counselors: event.target.value,
                  }))
                }
                placeholder="Amina KPB,Fatou Admin"
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, alignContent: 'end' }}>
              <span>Visibility</span>
              <input
                type="checkbox"
                checked={destinationForm.isVisible}
                onChange={(event) =>
                  setDestinationForm((current) => ({
                    ...current,
                    isVisible: event.target.checked,
                  }))
                }
              />
            </label>
            <button type="submit" style={{ ...buttonStyle, gridColumn: '1 / -1' }}>
              Add support destination
            </button>
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {supportDestinations.map((destination) => (
              <div
                key={destination.id}
                style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}
              >
                <strong>{destination.countryName.fr}</strong>
                <p style={{ margin: '6px 0' }}>
                  {destination.availableServiceTypes.join(', ')}
                </p>
                <span style={badgeStyle}>
                  {destination.status} • {destination.isVisible ? 'visible' : 'hidden'}
                </span>
              </div>
            ))}
          </div>
        </section>

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>Editorial content</h3>
            <p style={mutedTextStyle}>
              Publish guidance articles that can surface on home, scholarships,
              and community entry points.
            </p>
          </div>
          <form
            onSubmit={submitArticle}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
            <label style={labelStyle}>
              Slug
              <input
                value={articleForm.slug}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    slug: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Category
              <input
                value={articleForm.category}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    category: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Title (FR)
              <input
                value={articleForm.titleFr}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    titleFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Title (EN)
              <input
                value={articleForm.titleEn}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    titleEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Summary (FR)
              <textarea
                value={articleForm.summaryFr}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    summaryFr: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Summary (EN)
              <textarea
                value={articleForm.summaryEn}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    summaryEn: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Content (FR)
              <textarea
                value={articleForm.contentFr}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    contentFr: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Content (EN)
              <textarea
                value={articleForm.contentEn}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    contentEn: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={labelStyle}>
              Tags
              <input
                value={articleForm.tags}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    tags: event.target.value,
                  }))
                }
                placeholder="scholarships,canada,bachelor"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Author
              <input
                value={articleForm.authorName}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    authorName: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Status
              <select
                value={articleForm.status}
                onChange={(event) =>
                  setArticleForm((current) => ({
                    ...current,
                    status: event.target.value,
                  }))
                }
                style={inputStyle}
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
                <option value="archived">Archived</option>
              </select>
            </label>
            <button type="submit" style={{ ...buttonStyle, gridColumn: '1 / -1' }}>
              Add article
            </button>
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {articles.map((article) => (
              <div key={article.id} style={{ borderTop: '1px solid #E2E8F0', paddingTop: 12 }}>
                <strong>{article.title.fr}</strong>
                <p style={{ margin: '6px 0' }}>
                  {article.category} • {article.authorName}
                </p>
                <span style={badgeStyle}>{article.status}</span>
              </div>
            ))}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
