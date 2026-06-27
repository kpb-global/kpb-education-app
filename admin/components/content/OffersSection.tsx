'use client';

import { FormEvent, useEffect, useState } from 'react';

import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle, splitList } from '../../lib/ui';
import { useAdminAuth } from '../admin-auth-provider';
import {
  Alert,
  Button,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../ui';
import { CrudSection } from './CrudSection';

interface ServiceOfferItem {
  id: string;
  name: { fr: string; en: string };
  offerType: string;
  destinationIds: string[];
  studyLevels: string[];
  priceLabel: { fr: string; en: string };
  status: string;
  benefits?: { fr: string[]; en: string[] };
  ctaLabel?: { fr: string; en: string };
}

const EMPTY_FORM = {
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
};

const lines = (value: string) =>
  value
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);

const full = { gridColumn: '1 / -1' } as const;

export function OffersSection() {
  const { session } = useAdminAuth();
  const [items, setItems] = useState<ServiceOfferItem[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function load() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: ServiceOfferItem[] }>(
        '/admin/service-offers',
      );
      setItems(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load offers.',
      );
    }
  }

  useEffect(() => {
    if (!session) return;
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  function resetForm() {
    setForm(EMPTY_FORM);
    setEditingId(null);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      name: { fr: form.nameFr, en: form.nameEn },
      offerType: form.offerType,
      destinationIds: splitList(form.destinationIds),
      studyLevels: splitList(form.studyLevels),
      priceLabel: { fr: form.priceFr, en: form.priceEn },
      benefits: { fr: lines(form.benefitsFr), en: lines(form.benefitsEn) },
      ctaLabel: { fr: form.ctaFr, en: form.ctaEn },
      status: form.status,
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/service-offers/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Service offer updated successfully.');
      } else {
        await apiFetch('/admin/service-offers', { method: 'POST', body });
        setStatusMessage('Service offer published to the operations catalog.');
      }
      resetForm();
      await load();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create offer.',
      );
    }
  }

  function startEdit(offer: ServiceOfferItem) {
    setEditingId(offer.id);
    setForm({
      nameFr: offer.name.fr,
      nameEn: offer.name.en,
      offerType: offer.offerType,
      destinationIds: offer.destinationIds.join(','),
      studyLevels: offer.studyLevels.join(','),
      priceFr: offer.priceLabel.fr,
      priceEn: offer.priceLabel.en,
      benefitsFr: offer.benefits?.fr.join('\n') ?? '',
      benefitsEn: offer.benefits?.en.join('\n') ?? '',
      ctaFr: offer.ctaLabel?.fr ?? '',
      ctaEn: offer.ctaLabel?.en ?? '',
      status: offer.status,
    });
  }

  const form_ = (
    <form
      onSubmit={submit}
      style={{ display: 'grid', gap: 'var(--space-3)', gridTemplateColumns: '1fr 1fr' }}
    >
      <Field label="Offer name (FR)">
        {({ id }) => (
          <Input id={id} value={form.nameFr} onChange={(e) => setForm((c) => ({ ...c, nameFr: e.target.value }))} />
        )}
      </Field>
      <Field label="Offer name (EN)">
        {({ id }) => (
          <Input id={id} value={form.nameEn} onChange={(e) => setForm((c) => ({ ...c, nameEn: e.target.value }))} />
        )}
      </Field>
      <Field label="Offer type">
        {({ id }) => (
          <Input id={id} value={form.offerType} onChange={(e) => setForm((c) => ({ ...c, offerType: e.target.value }))} />
        )}
      </Field>
      <Field label="Status">
        {({ id }) => (
          <Select id={id} value={form.status} onChange={(e) => setForm((c) => ({ ...c, status: e.target.value }))}>
            <option value="draft">Draft</option>
            <option value="published">Published</option>
            <option value="archived">Archived</option>
          </Select>
        )}
      </Field>
      <Field label="Destination IDs (comma-separated)">
        {({ id }) => (
          <Input id={id} value={form.destinationIds} placeholder="can,fra,deu" onChange={(e) => setForm((c) => ({ ...c, destinationIds: e.target.value }))} />
        )}
      </Field>
      <Field label="Study levels (comma-separated)">
        {({ id }) => (
          <Input id={id} value={form.studyLevels} placeholder="high_school,bachelor,master" onChange={(e) => setForm((c) => ({ ...c, studyLevels: e.target.value }))} />
        )}
      </Field>
      <Field label="Price label (FR)">
        {({ id }) => (
          <Input id={id} value={form.priceFr} onChange={(e) => setForm((c) => ({ ...c, priceFr: e.target.value }))} />
        )}
      </Field>
      <Field label="Price label (EN)">
        {({ id }) => (
          <Input id={id} value={form.priceEn} onChange={(e) => setForm((c) => ({ ...c, priceEn: e.target.value }))} />
        )}
      </Field>
      <div style={full}>
        <Field label="Benefits (FR, one per line)">
          {({ id }) => (
            <Textarea id={id} value={form.benefitsFr} onChange={(e) => setForm((c) => ({ ...c, benefitsFr: e.target.value }))} />
          )}
        </Field>
      </div>
      <div style={full}>
        <Field label="Benefits (EN, one per line)">
          {({ id }) => (
            <Textarea id={id} value={form.benefitsEn} onChange={(e) => setForm((c) => ({ ...c, benefitsEn: e.target.value }))} />
          )}
        </Field>
      </div>
      <Field label="CTA (FR)">
        {({ id }) => (
          <Input id={id} value={form.ctaFr} onChange={(e) => setForm((c) => ({ ...c, ctaFr: e.target.value }))} />
        )}
      </Field>
      <Field label="CTA (EN)">
        {({ id }) => (
          <Input id={id} value={form.ctaEn} onChange={(e) => setForm((c) => ({ ...c, ctaEn: e.target.value }))} />
        )}
      </Field>
      <div style={{ ...full, display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
        <Button type="submit">{editingId ? 'Update service offer' : 'Add service offer'}</Button>
        {editingId ? (
          <Button type="button" variant="secondary" onClick={resetForm}>
            Cancel
          </Button>
        ) : null}
      </div>
    </form>
  );

  return (
    <div style={{ display: 'grid', gap: 'var(--space-4)' }}>
      {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
      {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}
      <CrudSection
        title="Service offers"
        description="Add a new KPB premium or consultative offer that can surface in the mobile app."
        form={form_}
        items={items}
        getKey={(offer) => offer.id}
        editingId={editingId}
        onSelect={startEdit}
        emptyLabel="No service offers yet."
        renderItem={(offer) => (
          <>
            <strong>{offer.name.fr}</strong>
            <span style={{ ...mutedTextStyle, fontSize: 'var(--text-sm)' }}>
              {offer.offerType} • {offer.destinationIds.join(', ') || 'global'}
            </span>
            <span>
              <StatusBadge status={offer.status} />
            </span>
          </>
        )}
      />
    </div>
  );
}
