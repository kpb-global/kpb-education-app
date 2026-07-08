'use client';

import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
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
  benefits?: { fr?: string[]; en?: string[] };
  ctaLabel?: { fr?: string; en?: string };
  status: string;
}

interface SupportDestinationItem {
  id: string;
  countryId?: string;
  countryName: { fr: string; en: string };
  supportLanguages: string[];
  availableServiceTypes: string[];
  conditions?: { fr?: string[]; en?: string[] };
  counselorNames: string[];
  isVisible: boolean;
  status: string;
}

interface ArticleItem {
  id: string;
  slug?: string;
  title: { fr: string; en: string };
  category: string;
  summary?: { fr?: string; en?: string };
  content?: { fr?: string; en?: string };
  tags?: string[];
  authorName: string;
  status: string;
}

interface ParcoursQa {
  question: string;
  answer: string;
}

interface ParcoursItem {
  id: string;
  slug: string;
  kind: 'video' | 'text';
  fieldId: string | null;
  tags: string[];
  personName: string;
  role: { fr: string; en: string };
  title: { fr: string; en: string };
  hook?: { fr?: string; en?: string };
  summary?: { fr?: string; en?: string };
  thumbnailUrl?: string;
  photoUrl?: string;
  youtubeId: string | null;
  durationMinutes: number | null;
  interview?: { fr?: ParcoursQa[] | null; en?: ParcoursQa[] | null };
  status: string;
  featured: boolean;
  displayOrder: number;
}

// Catalog field domains (d01..d12) — kept in sync with the backend
// orientation-fields taxonomy so the theme filter matches the mobile app.
const PARCOURS_FIELD_OPTIONS: { id: string; label: string }[] = [
  { id: '', label: '— Unmapped (no theme)' },
  { id: 'd01', label: 'Informatique & IA' },
  { id: 'd02', label: 'Commerce & Management' },
  { id: 'd03', label: 'Ingénierie & Sciences' },
  { id: 'd04', label: 'Santé & Sciences de la Vie' },
  { id: 'd05', label: 'Architecture & BTP' },
  { id: 'd06', label: 'Design, Médias & Communication' },
  { id: 'd07', label: 'Droit & Relations Internationales' },
  { id: 'd08', label: 'Environnement & Agriculture' },
  { id: 'd09', label: 'Sciences Humaines & Éducation' },
  { id: 'd10', label: 'Hôtellerie & Tourisme' },
  { id: 'd11', label: 'Arts & Culture' },
  { id: 'd12', label: 'Logistique & Supply Chain' },
];

const EMPTY_PARCOURS_FORM = {
  slug: '',
  kind: 'video',
  fieldId: 'd01',
  youtubeId: '',
  personName: '',
  roleFr: '',
  roleEn: '',
  titleFr: '',
  titleEn: '',
  hookFr: '',
  hookEn: '',
  summaryFr: '',
  summaryEn: '',
  tags: '',
  durationMinutes: '',
  thumbnailUrl: '',
  photoUrl: '',
  interviewFr: '',
  interviewEn: '',
  status: 'published',
  featured: false,
};

// Parse the admin interview textarea (JSON array of {question, answer}).
// Returns null for empty input; throws a readable error for invalid JSON so
// submitParcours can surface it instead of silently dropping the content.
function parseInterview(raw: string, label: string): ParcoursQa[] | null {
  const trimmed = raw.trim();
  if (trimmed === '') return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    throw new Error(`Interview ${label}: invalid JSON.`);
  }
  if (!Array.isArray(parsed)) {
    throw new Error(`Interview ${label}: expected a JSON array of {question, answer}.`);
  }
  return parsed.map((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new Error(`Interview ${label}: item ${index + 1} is not an object.`);
    }
    const record = item as Record<string, unknown>;
    return {
      question: String(record.question ?? ''),
      answer: String(record.answer ?? ''),
    };
  });
}

export default function ContentPage() {
  const { session } = useAdminAuth();
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
  const [parcours, setParcours] = useState<ParcoursItem[]>([]);
  const [parcoursForm, setParcoursForm] = useState({ ...EMPTY_PARCOURS_FORM });
  const [editingOfferId, setEditingOfferId] = useState<string | null>(null);
  const [editingDestinationId, setEditingDestinationId] = useState<string | null>(null);
  const [editingArticleId, setEditingArticleId] = useState<string | null>(null);
  const [editingParcoursId, setEditingParcoursId] = useState<string | null>(null);

  async function loadContent() {
    setErrorMessage(null);
    try {
      const [
        offersResponse,
        destinationsResponse,
        articlesResponse,
        parcoursResponse,
      ] = await Promise.all([
        apiFetch<{ items: ServiceOfferItem[] }>('/admin/service-offers'),
        apiFetch<{ items: SupportDestinationItem[] }>(
          '/admin/support-destinations',
        ),
        apiFetch<{ items: ArticleItem[] }>('/admin/articles'),
        apiFetch<{ items: ParcoursItem[] }>('/admin/parcours'),
      ]);
      setServiceOffers(offersResponse.items);
      setSupportDestinations(destinationsResponse.items);
      setArticles(articlesResponse.items);
      setParcours(parcoursResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load content.',
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadContent();
  }, [session]);

  async function submitOffer(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      if (editingOfferId) {
        await apiFetch(`/admin/service-offers/${editingOfferId}`, {
          method: 'PATCH',
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
        setStatusMessage('Service offer updated successfully.');
      } else {
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
        setStatusMessage('Service offer published to the operations catalog.');
      }

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
      setEditingOfferId(null);
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
      if (editingDestinationId) {
        await apiFetch(`/admin/support-destinations/${editingDestinationId}`, {
          method: 'PATCH',
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
        setStatusMessage('Support destination updated successfully.');
      } else {
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
        setStatusMessage('Support destination added successfully.');
      }

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
      setEditingDestinationId(null);
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
      if (editingArticleId) {
        await apiFetch(`/admin/articles/${editingArticleId}`, {
          method: 'PATCH',
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
        setStatusMessage('Article updated successfully.');
      } else {
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
        setStatusMessage('Article added to the editorial queue.');
      }

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
      setEditingArticleId(null);
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create article.',
      );
    }
  }

  async function submitParcours(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const durationRaw = parcoursForm.durationMinutes.trim();
    const duration = durationRaw === '' ? null : Number(durationRaw);

    let interviewFr: ParcoursQa[] | null;
    let interviewEn: ParcoursQa[] | null;
    try {
      interviewFr = parseInterview(parcoursForm.interviewFr, 'FR');
      interviewEn = parseInterview(parcoursForm.interviewEn, 'EN');
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Invalid interview JSON.',
      );
      return;
    }

    // Shared body — NOTE: `source` is intentionally omitted so an edit never
    // clobbers the provenance ('excel'/'legacy_db') of an imported story.
    const body: Record<string, unknown> = {
      slug:
        parcoursForm.slug.trim() ||
        `parcours-${parcoursForm.titleFr
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-|-$)/g, '')
          .slice(0, 48)}`,
      kind: parcoursForm.kind,
      fieldId: parcoursForm.fieldId || null,
      youtubeId: parcoursForm.youtubeId.trim() || null,
      durationMinutes:
        duration !== null && Number.isFinite(duration) ? duration : null,
      personName: parcoursForm.personName,
      role: { fr: parcoursForm.roleFr, en: parcoursForm.roleEn },
      title: { fr: parcoursForm.titleFr, en: parcoursForm.titleEn },
      hook: { fr: parcoursForm.hookFr, en: parcoursForm.hookEn },
      summary: { fr: parcoursForm.summaryFr, en: parcoursForm.summaryEn },
      thumbnailUrl: parcoursForm.thumbnailUrl.trim(),
      photoUrl: parcoursForm.photoUrl.trim(),
      interview: { fr: interviewFr, en: interviewEn },
      tags: splitList(parcoursForm.tags),
      status: parcoursForm.status,
      featured: parcoursForm.featured,
    };

    try {
      if (editingParcoursId) {
        await apiFetch(`/admin/parcours/${editingParcoursId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Parcours story updated successfully.');
      } else {
        // Only new rows are stamped as manually authored.
        await apiFetch('/admin/parcours', {
          method: 'POST',
          body: { ...body, source: 'manual' },
        });
        setStatusMessage('Parcours story added.');
      }
      setParcoursForm({ ...EMPTY_PARCOURS_FORM });
      setEditingParcoursId(null);
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to save the parcours story.',
      );
    }
  }

  async function deleteParcours(id: string) {
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/parcours/${id}`, { method: 'DELETE' });
      if (editingParcoursId === id) {
        setEditingParcoursId(null);
        setParcoursForm({ ...EMPTY_PARCOURS_FORM });
      }
      setStatusMessage('Parcours story deleted.');
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to delete the parcours story.',
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
              {editingOfferId ? 'Update service offer' : 'Add service offer'}
            </button>
            {editingOfferId && (
              <button
                type="button"
                onClick={() => {
                  setEditingOfferId(null);
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
                }}
                style={{ ...buttonStyle, gridColumn: '1 / -1', background: '#64748b' }}
              >
                Cancel
              </button>
            )}
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {serviceOffers.map((offer) => (
              <div 
                key={offer.id} 
                onClick={() => {
                  setEditingOfferId(offer.id);
                  setOfferForm({
                    nameFr: offer.name.fr,
                    nameEn: offer.name.en,
                    offerType: offer.offerType,
                    destinationIds: offer.destinationIds.join(','),
                    studyLevels: offer.studyLevels.join(','),
                    priceFr: offer.priceLabel.fr,
                    priceEn: offer.priceLabel.en,
                    benefitsFr: offer.benefits?.fr?.join('\n') ?? '',
                    benefitsEn: offer.benefits?.en?.join('\n') ?? '',
                    ctaFr: offer.ctaLabel?.fr ?? '',
                    ctaEn: offer.ctaLabel?.en ?? '',
                    status: offer.status,
                  });
                }}
                style={{ 
                  borderTop: '1px solid #E2E8F0', 
                  paddingTop: 12,
                  cursor: 'pointer',
                  background: editingOfferId === offer.id ? '#f1f5f9' : 'transparent',
                  padding: '12px 8px',
                  borderRadius: 8,
                }}
              >
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
              {editingDestinationId ? 'Update support destination' : 'Add support destination'}
            </button>
            {editingDestinationId && (
              <button
                type="button"
                onClick={() => {
                  setEditingDestinationId(null);
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
                }}
                style={{ ...buttonStyle, gridColumn: '1 / -1', background: '#64748b' }}
              >
                Cancel
              </button>
            )}
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {supportDestinations.map((destination) => (
              <div
                key={destination.id}
                onClick={() => {
                  setEditingDestinationId(destination.id);
                  setDestinationForm({
                    countryId: destination.countryId ?? '',
                    countryFr: destination.countryName.fr,
                    countryEn: destination.countryName.en,
                    supportLanguages: destination.supportLanguages.join(','),
                    serviceTypes: destination.availableServiceTypes.join(','),
                    conditionsFr: destination.conditions?.fr?.join('\n') ?? '',
                    conditionsEn: destination.conditions?.en?.join('\n') ?? '',
                    counselors: destination.counselorNames.join(','),
                    isVisible: destination.isVisible,
                    status: destination.status,
                  });
                }}
                style={{ 
                  borderTop: '1px solid #E2E8F0', 
                  paddingTop: 12,
                  cursor: 'pointer',
                  background: editingDestinationId === destination.id ? '#f1f5f9' : 'transparent',
                  padding: '12px 8px',
                  borderRadius: 8,
                }}
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
              {editingArticleId ? 'Update article' : 'Add article'}
            </button>
            {editingArticleId && (
              <button
                type="button"
                onClick={() => {
                  setEditingArticleId(null);
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
                }}
                style={{ ...buttonStyle, gridColumn: '1 / -1', background: '#64748b' }}
              >
                Cancel
              </button>
            )}
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {articles.map((article) => (
              <div 
                key={article.id} 
                onClick={() => {
                  setEditingArticleId(article.id);
                  setArticleForm({
                    slug: article.slug ?? '',
                    category: article.category,
                    titleFr: article.title.fr,
                    titleEn: article.title.en,
                    summaryFr: article.summary?.fr ?? '',
                    summaryEn: article.summary?.en ?? '',
                    contentFr: article.content?.fr ?? '',
                    contentEn: article.content?.en ?? '',
                    tags: article.tags?.join(',') ?? '',
                    authorName: article.authorName,
                    status: article.status,
                  });
                }}
                style={{ 
                  borderTop: '1px solid #E2E8F0', 
                  paddingTop: 12,
                  cursor: 'pointer',
                  background: editingArticleId === article.id ? '#f1f5f9' : 'transparent',
                  padding: '12px 8px',
                  borderRadius: 8,
                }}
              >
                <strong>{article.title.fr}</strong>
                <p style={{ margin: '6px 0' }}>
                  {article.category} • {article.authorName}
                </p>
                <span style={badgeStyle}>{article.status}</span>
              </div>
            ))}
          </div>
        </section>

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>Parcours & témoignages</h3>
            <p style={mutedTextStyle}>
              Manage the free &quot;Parcours&quot; stories shown in the mobile
              app — curated YouTube videos and imported written interviews.
              Fill the YouTube ID for a video story; leave it empty for a
              written testimonial.
            </p>
          </div>
          <form
            onSubmit={submitParcours}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
            <label style={labelStyle}>
              Kind
              <select
                value={parcoursForm.kind}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    kind: event.target.value,
                  }))
                }
                style={inputStyle}
              >
                <option value="video">Video</option>
                <option value="text">Written interview</option>
              </select>
            </label>
            <label style={labelStyle}>
              Field domain
              <select
                value={parcoursForm.fieldId}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    fieldId: event.target.value,
                  }))
                }
                style={inputStyle}
              >
                {PARCOURS_FIELD_OPTIONS.map((f) => (
                  <option key={f.id} value={f.id}>
                    {f.id} — {f.label}
                  </option>
                ))}
              </select>
            </label>
            <label style={labelStyle}>
              YouTube ID (video only)
              <input
                value={parcoursForm.youtubeId}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    youtubeId: event.target.value,
                  }))
                }
                placeholder="e.g. l_0UPSeH5sU"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Duration (minutes)
              <input
                value={parcoursForm.durationMinutes}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    durationMinutes: event.target.value,
                  }))
                }
                inputMode="numeric"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Person name
              <input
                value={parcoursForm.personName}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    personName: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Slug (optional)
              <input
                value={parcoursForm.slug}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    slug: event.target.value,
                  }))
                }
                placeholder="auto from title if empty"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Role (FR)
              <input
                value={parcoursForm.roleFr}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    roleFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Role (EN)
              <input
                value={parcoursForm.roleEn}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    roleEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Title (FR)
              <input
                value={parcoursForm.titleFr}
                onChange={(event) =>
                  setParcoursForm((current) => ({
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
                value={parcoursForm.titleEn}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    titleEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Hook / one-liner (FR)
              <input
                value={parcoursForm.hookFr}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    hookFr: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Hook / one-liner (EN)
              <input
                value={parcoursForm.hookEn}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    hookEn: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Summary (FR)
              <textarea
                value={parcoursForm.summaryFr}
                onChange={(event) =>
                  setParcoursForm((current) => ({
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
                value={parcoursForm.summaryEn}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    summaryEn: event.target.value,
                  }))
                }
                style={textareaStyle}
              />
            </label>
            <label style={labelStyle}>
              Thumbnail URL (optional — videos derive one from the YouTube ID)
              <input
                value={parcoursForm.thumbnailUrl}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    thumbnailUrl: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Photo URL (person portrait, optional)
              <input
                value={parcoursForm.photoUrl}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    photoUrl: event.target.value,
                  }))
                }
                style={inputStyle}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Interview FR — JSON array of {'{ question, answer }'} (written
              stories only)
              <textarea
                value={parcoursForm.interviewFr}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    interviewFr: event.target.value,
                  }))
                }
                placeholder={'[\n  { "question": "…", "answer": "…" }\n]'}
                style={{ ...textareaStyle, minHeight: 120, fontFamily: 'monospace' }}
              />
            </label>
            <label style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Interview EN — JSON array of {'{ question, answer }'} (optional;
              falls back to FR)
              <textarea
                value={parcoursForm.interviewEn}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    interviewEn: event.target.value,
                  }))
                }
                placeholder={'[\n  { "question": "…", "answer": "…" }\n]'}
                style={{ ...textareaStyle, minHeight: 120, fontFamily: 'monospace' }}
              />
            </label>
            <label style={labelStyle}>
              Tags
              <input
                value={parcoursForm.tags}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    tags: event.target.value,
                  }))
                }
                placeholder="Google,Tech,Témoignage"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Status
              <select
                value={parcoursForm.status}
                onChange={(event) =>
                  setParcoursForm((current) => ({
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
            <label
              style={{
                ...labelStyle,
                flexDirection: 'row',
                alignItems: 'center',
                gap: 8,
              }}
            >
              <input
                type="checkbox"
                checked={parcoursForm.featured}
                onChange={(event) =>
                  setParcoursForm((current) => ({
                    ...current,
                    featured: event.target.checked,
                  }))
                }
              />
              Featured
            </label>
            <button type="submit" style={{ ...buttonStyle, gridColumn: '1 / -1' }}>
              {editingParcoursId ? 'Update story' : 'Add story'}
            </button>
            {editingParcoursId && (
              <button
                type="button"
                onClick={() => {
                  setEditingParcoursId(null);
                  setParcoursForm({ ...EMPTY_PARCOURS_FORM });
                }}
                style={{ ...buttonStyle, gridColumn: '1 / -1', background: '#64748b' }}
              >
                Cancel
              </button>
            )}
          </form>
          <div style={{ display: 'grid', gap: 12 }}>
            {parcours.map((story) => (
              <div
                key={story.id}
                style={{
                  borderTop: '1px solid #E2E8F0',
                  paddingTop: 12,
                  background:
                    editingParcoursId === story.id ? '#f1f5f9' : 'transparent',
                  padding: '12px 8px',
                  borderRadius: 8,
                }}
              >
                <div
                  onClick={() => {
                    setEditingParcoursId(story.id);
                    setParcoursForm({
                      slug: story.slug,
                      kind: story.kind,
                      fieldId: story.fieldId ?? '',
                      youtubeId: story.youtubeId ?? '',
                      personName: story.personName ?? '',
                      roleFr: story.role?.fr ?? '',
                      roleEn: story.role?.en ?? '',
                      titleFr: story.title?.fr ?? '',
                      titleEn: story.title?.en ?? '',
                      hookFr: story.hook?.fr ?? '',
                      hookEn: story.hook?.en ?? '',
                      summaryFr: story.summary?.fr ?? '',
                      summaryEn: story.summary?.en ?? '',
                      tags: story.tags?.join(',') ?? '',
                      durationMinutes:
                        story.durationMinutes != null
                          ? String(story.durationMinutes)
                          : '',
                      thumbnailUrl: story.thumbnailUrl ?? '',
                      photoUrl: story.photoUrl ?? '',
                      interviewFr: story.interview?.fr
                        ? JSON.stringify(story.interview.fr, null, 2)
                        : '',
                      interviewEn: story.interview?.en
                        ? JSON.stringify(story.interview.en, null, 2)
                        : '',
                      status: story.status,
                      featured: story.featured,
                    });
                  }}
                  style={{ cursor: 'pointer' }}
                >
                  <strong>{story.title.fr}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {story.kind === 'video' ? '🎬 Video' : '📝 Written'}
                    {story.fieldId ? ` • ${story.fieldId}` : ''}
                    {story.personName ? ` • ${story.personName}` : ''}
                    {story.featured ? ' • ⭐ Featured' : ''}
                  </p>
                  <span style={badgeStyle}>{story.status}</span>
                </div>
                <button
                  type="button"
                  onClick={() => deleteParcours(story.id)}
                  style={{
                    ...buttonStyle,
                    marginTop: 8,
                    background: '#B91C1C',
                    width: 'fit-content',
                    padding: '6px 12px',
                  }}
                >
                  Delete
                </button>
              </div>
            ))}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
