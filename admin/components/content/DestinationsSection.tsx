'use client';

import { FormEvent, useEffect, useState } from 'react';

import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle, splitList } from '../../lib/ui';
import { useAdminAuth } from '../admin-auth-provider';
import {
  Alert,
  Badge,
  Button,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../ui';
import { CrudSection } from './CrudSection';

interface SupportDestinationItem {
  id: string;
  countryId?: string;
  countryName: { fr: string; en: string };
  supportLanguages: string[];
  availableServiceTypes: string[];
  counselorNames: string[];
  isVisible: boolean;
  status: string;
  conditions?: { fr: string[]; en: string[] };
}

const EMPTY_FORM = {
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
};

const lines = (value: string) =>
  value
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);

const full = { gridColumn: '1 / -1' } as const;

export function DestinationsSection() {
  const { session } = useAdminAuth();
  const [items, setItems] = useState<SupportDestinationItem[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function load() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: SupportDestinationItem[] }>(
        '/admin/support-destinations',
      );
      setItems(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load destinations.',
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
      countryId: form.countryId,
      countryName: { fr: form.countryFr, en: form.countryEn },
      supportLanguages: splitList(form.supportLanguages),
      availableServiceTypes: splitList(form.serviceTypes),
      conditions: { fr: lines(form.conditionsFr), en: lines(form.conditionsEn) },
      counselorNames: splitList(form.counselors),
      isVisible: form.isVisible,
      status: form.status,
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/support-destinations/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Support destination updated successfully.');
      } else {
        await apiFetch('/admin/support-destinations', { method: 'POST', body });
        setStatusMessage('Support destination added successfully.');
      }
      resetForm();
      await load();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to create support destination.',
      );
    }
  }

  function startEdit(destination: SupportDestinationItem) {
    setEditingId(destination.id);
    setForm({
      countryId: destination.countryId ?? '',
      countryFr: destination.countryName.fr,
      countryEn: destination.countryName.en,
      supportLanguages: destination.supportLanguages.join(','),
      serviceTypes: destination.availableServiceTypes.join(','),
      conditionsFr: destination.conditions?.fr.join('\n') ?? '',
      conditionsEn: destination.conditions?.en.join('\n') ?? '',
      counselors: destination.counselorNames.join(','),
      isVisible: destination.isVisible,
      status: destination.status,
    });
  }

  const form_ = (
    <form
      onSubmit={submit}
      style={{ display: 'grid', gap: 'var(--space-3)', gridTemplateColumns: '1fr 1fr' }}
    >
      <Field label="Country ID">
        {({ id }) => (
          <Input id={id} value={form.countryId} placeholder="can" onChange={(e) => setForm((c) => ({ ...c, countryId: e.target.value }))} />
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
      <Field label="Country name (FR)">
        {({ id }) => (
          <Input id={id} value={form.countryFr} onChange={(e) => setForm((c) => ({ ...c, countryFr: e.target.value }))} />
        )}
      </Field>
      <Field label="Country name (EN)">
        {({ id }) => (
          <Input id={id} value={form.countryEn} onChange={(e) => setForm((c) => ({ ...c, countryEn: e.target.value }))} />
        )}
      </Field>
      <Field label="Support languages (comma-separated)">
        {({ id }) => (
          <Input id={id} value={form.supportLanguages} onChange={(e) => setForm((c) => ({ ...c, supportLanguages: e.target.value }))} />
        )}
      </Field>
      <Field label="Service types (comma-separated)">
        {({ id }) => (
          <Input id={id} value={form.serviceTypes} onChange={(e) => setForm((c) => ({ ...c, serviceTypes: e.target.value }))} />
        )}
      </Field>
      <div style={full}>
        <Field label="Conditions (FR, one per line)">
          {({ id }) => (
            <Textarea id={id} value={form.conditionsFr} onChange={(e) => setForm((c) => ({ ...c, conditionsFr: e.target.value }))} />
          )}
        </Field>
      </div>
      <div style={full}>
        <Field label="Conditions (EN, one per line)">
          {({ id }) => (
            <Textarea id={id} value={form.conditionsEn} onChange={(e) => setForm((c) => ({ ...c, conditionsEn: e.target.value }))} />
          )}
        </Field>
      </div>
      <Field label="Counselors (comma-separated)">
        {({ id }) => (
          <Input id={id} value={form.counselors} placeholder="Amina KPB,Fatou Admin" onChange={(e) => setForm((c) => ({ ...c, counselors: e.target.value }))} />
        )}
      </Field>
      <label style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center', fontWeight: 600 }}>
        <input
          type="checkbox"
          checked={form.isVisible}
          onChange={(e) => setForm((c) => ({ ...c, isVisible: e.target.checked }))}
        />
        Visible in app
      </label>
      <div style={{ ...full, display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
        <Button type="submit">
          {editingId ? 'Update support destination' : 'Add support destination'}
        </Button>
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
        title="Support destinations"
        description="Control which accompaniment countries appear in the mobile explore experience."
        form={form_}
        items={items}
        getKey={(destination) => destination.id}
        editingId={editingId}
        onSelect={startEdit}
        emptyLabel="No support destinations yet."
        renderItem={(destination) => (
          <>
            <strong>{destination.countryName.fr}</strong>
            <span style={{ ...mutedTextStyle, fontSize: 'var(--text-sm)' }}>
              {destination.availableServiceTypes.join(', ')}
            </span>
            <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <StatusBadge status={destination.status} />
              <Badge variant={destination.isVisible ? 'success' : 'neutral'}>
                {destination.isVisible ? 'visible' : 'hidden'}
              </Badge>
            </span>
          </>
        )}
      />
    </div>
  );
}
