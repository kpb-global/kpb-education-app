'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import {
  CheckboxField,
  StatusBanners,
  TextAreaField,
  TextField,
} from '../../components/form-controls';
import { apiFetch } from '../../lib/api-client';
import {
  CountryRow,
  fetchCountries,
  fetchFields,
  FieldOption,
} from '../../lib/catalog-api';
import {
  badgeStyle,
  buttonStyle,
  mutedTextStyle,
  panelStyle,
  secondaryButtonStyle,
} from '../../lib/ui';

interface CountryForm {
  code: string;
  flagEmoji: string;
  nameFr: string;
  nameEn: string;
  taglineFr: string;
  taglineEn: string;
  whyStudyFr: string;
  whyStudyEn: string;
  tuitionRangeFr: string;
  tuitionRangeEn: string;
  livingCostRangeFr: string;
  livingCostRangeEn: string;
  visaOverviewFr: string;
  visaOverviewEn: string;
  admissionDifficultyFr: string;
  admissionDifficultyEn: string;
  popularFieldIds: string[];
  displayOrder: string;
  isActive: boolean;
}

const emptyForm: CountryForm = {
  code: '',
  flagEmoji: '',
  nameFr: '',
  nameEn: '',
  taglineFr: '',
  taglineEn: '',
  whyStudyFr: '',
  whyStudyEn: '',
  tuitionRangeFr: '',
  tuitionRangeEn: '',
  livingCostRangeFr: '',
  livingCostRangeEn: '',
  visaOverviewFr: '',
  visaOverviewEn: '',
  admissionDifficultyFr: '',
  admissionDifficultyEn: '',
  popularFieldIds: [],
  displayOrder: '0',
  isActive: true,
};

export default function CountriesPage() {
  const [countries, setCountries] = useState<CountryRow[]>([]);
  const [fields, setFields] = useState<FieldOption[]>([]);
  const [form, setForm] = useState<CountryForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadCountries() {
    setErrorMessage(null);
    try {
      const response = await fetchCountries();
      setCountries(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load countries.',
      );
    }
  }

  async function loadFields() {
    try {
      const response = await fetchFields();
      setFields(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load fields.',
      );
    }
  }

  useEffect(() => {
    void loadCountries();
    void loadFields();
  }, []);

  const fieldName = useMemo(() => {
    const map = new Map<string, string>();
    fields.forEach((field) => map.set(field.id, field.nameFr));
    return map;
  }, [fields]);

  function togglePopularField(fieldId: string) {
    setForm((current) => ({
      ...current,
      popularFieldIds: current.popularFieldIds.includes(fieldId)
        ? current.popularFieldIds.filter((id) => id !== fieldId)
        : [...current.popularFieldIds, fieldId],
    }));
  }

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(country: CountryRow) {
    setEditingId(country.id);
    setStatusMessage(null);
    setErrorMessage(null);
    setForm({
      code: country.code,
      flagEmoji: country.flagEmoji,
      nameFr: country.nameFr,
      nameEn: country.nameEn,
      taglineFr: country.taglineFr,
      taglineEn: country.taglineEn,
      whyStudyFr: country.whyStudyFr,
      whyStudyEn: country.whyStudyEn,
      tuitionRangeFr: country.tuitionRangeFr,
      tuitionRangeEn: country.tuitionRangeEn,
      livingCostRangeFr: country.livingCostRangeFr,
      livingCostRangeEn: country.livingCostRangeEn,
      visaOverviewFr: country.visaOverviewFr,
      visaOverviewEn: country.visaOverviewEn,
      admissionDifficultyFr: country.admissionDifficultyFr,
      admissionDifficultyEn: country.admissionDifficultyEn,
      popularFieldIds: country.popularFieldIds,
      displayOrder: String(country.displayOrder),
      isActive: country.isActive,
    });
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const orderValue = Number(form.displayOrder);
    const body = {
      code: form.code.trim(),
      flagEmoji: form.flagEmoji.trim() || '🌍',
      nameFr: form.nameFr,
      nameEn: form.nameEn,
      taglineFr: form.taglineFr,
      taglineEn: form.taglineEn,
      whyStudyFr: form.whyStudyFr,
      whyStudyEn: form.whyStudyEn,
      tuitionRangeFr: form.tuitionRangeFr,
      tuitionRangeEn: form.tuitionRangeEn,
      livingCostRangeFr: form.livingCostRangeFr,
      livingCostRangeEn: form.livingCostRangeEn,
      visaOverviewFr: form.visaOverviewFr,
      visaOverviewEn: form.visaOverviewEn,
      admissionDifficultyFr: form.admissionDifficultyFr,
      admissionDifficultyEn: form.admissionDifficultyEn,
      popularFieldIds: form.popularFieldIds,
      displayOrder: Number.isFinite(orderValue) ? orderValue : 0,
      isActive: form.isActive,
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/catalog/countries/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Country updated.');
      } else {
        await apiFetch('/admin/catalog/countries', { method: 'POST', body });
        setStatusMessage('Country created.');
      }
      resetForm();
      await loadCountries();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to save country.',
      );
    }
  }

  async function remove(country: CountryRow) {
    if (
      !window.confirm(
        `Delete country "${country.nameFr}"? This cannot be undone.`,
      )
    ) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/catalog/countries/${country.id}`, {
        method: 'DELETE',
      });
      if (editingId === country.id) {
        resetForm();
      }
      setStatusMessage('Country deleted.');
      await loadCountries();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to delete country.',
      );
    }
  }

  return (
    <DashboardShell title="Countries">
      <div style={{ display: 'grid', gap: 18 }}>
        <StatusBanners statusMessage={statusMessage} errorMessage={errorMessage} />

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>
              {editingId ? 'Edit country' : 'Add a country'}
            </h3>
            <p style={mutedTextStyle}>
              Study destinations surfaced in the mobile catalogue. A country with
              programs or institutions cannot be deleted — deactivate it instead.
            </p>
          </div>
          <form
            onSubmit={submit}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
            <TextField
              label="Code (ISO, unique)"
              value={form.code}
              placeholder="fra"
              onChange={(value) =>
                setForm((current) => ({ ...current, code: value }))
              }
            />
            <TextField
              label="Flag emoji"
              value={form.flagEmoji}
              placeholder="🇫🇷"
              onChange={(value) =>
                setForm((current) => ({ ...current, flagEmoji: value }))
              }
            />
            <TextField
              label="Name (FR)"
              value={form.nameFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, nameFr: value }))
              }
            />
            <TextField
              label="Name (EN)"
              value={form.nameEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, nameEn: value }))
              }
            />
            <TextField
              label="Tagline (FR)"
              value={form.taglineFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, taglineFr: value }))
              }
            />
            <TextField
              label="Tagline (EN)"
              value={form.taglineEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, taglineEn: value }))
              }
            />
            <TextField
              label="Tuition range (FR)"
              value={form.tuitionRangeFr}
              placeholder="3 000 – 12 000 € / an"
              onChange={(value) =>
                setForm((current) => ({ ...current, tuitionRangeFr: value }))
              }
            />
            <TextField
              label="Tuition range (EN)"
              value={form.tuitionRangeEn}
              placeholder="€3,000 – €12,000 / year"
              onChange={(value) =>
                setForm((current) => ({ ...current, tuitionRangeEn: value }))
              }
            />
            <TextField
              label="Living cost range (FR)"
              value={form.livingCostRangeFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, livingCostRangeFr: value }))
              }
            />
            <TextField
              label="Living cost range (EN)"
              value={form.livingCostRangeEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, livingCostRangeEn: value }))
              }
            />
            <TextField
              label="Admission difficulty (FR)"
              value={form.admissionDifficultyFr}
              placeholder="Sélectif"
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  admissionDifficultyFr: value,
                }))
              }
            />
            <TextField
              label="Admission difficulty (EN)"
              value={form.admissionDifficultyEn}
              placeholder="Selective"
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  admissionDifficultyEn: value,
                }))
              }
            />
            <TextAreaField
              label="Why study here (FR)"
              value={form.whyStudyFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, whyStudyFr: value }))
              }
            />
            <TextAreaField
              label="Why study here (EN)"
              value={form.whyStudyEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, whyStudyEn: value }))
              }
            />
            <TextAreaField
              label="Visa overview (FR)"
              value={form.visaOverviewFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, visaOverviewFr: value }))
              }
            />
            <TextAreaField
              label="Visa overview (EN)"
              value={form.visaOverviewEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, visaOverviewEn: value }))
              }
            />
            <TextField
              label="Display order"
              value={form.displayOrder}
              type="number"
              onChange={(value) =>
                setForm((current) => ({ ...current, displayOrder: value }))
              }
            />
            <CheckboxField
              label="Active (visible in app)"
              checked={form.isActive}
              onChange={(checked) =>
                setForm((current) => ({ ...current, isActive: checked }))
              }
            />
            <div style={{ gridColumn: '1 / -1', display: 'grid', gap: 8 }}>
              <span style={{ fontWeight: 600 }}>Popular fields</span>
              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: 10,
                  fontWeight: 400,
                }}
              >
                {fields.length === 0 ? (
                  <span style={mutedTextStyle}>No fields available.</span>
                ) : (
                  fields.map((field) => (
                    <label
                      key={field.id}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        border: '1px solid #E2E8F0',
                        borderRadius: 999,
                        padding: '6px 12px',
                        cursor: 'pointer',
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={form.popularFieldIds.includes(field.id)}
                        onChange={() => togglePopularField(field.id)}
                      />
                      {field.nameFr}
                    </label>
                  ))
                )}
              </div>
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 12 }}>
              <button type="submit" style={{ ...buttonStyle, flex: 1 }}>
                {editingId ? 'Update country' : 'Add country'}
              </button>
              {editingId ? (
                <button
                  type="button"
                  onClick={resetForm}
                  style={{ ...secondaryButtonStyle, flex: 1 }}
                >
                  Cancel
                </button>
              ) : null}
            </div>
          </form>
        </section>

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <p style={mutedTextStyle}>{countries.length} country(ies).</p>
          <div style={{ display: 'grid', gap: 12 }}>
            {countries.map((country) => (
              <div
                key={country.id}
                style={{
                  border:
                    editingId === country.id
                      ? '2px solid #1D4ED8'
                      : '1px solid #E2E8F0',
                  borderRadius: 16,
                  padding: 14,
                  display: 'flex',
                  justifyContent: 'space-between',
                  gap: 12,
                  alignItems: 'flex-start',
                }}
              >
                <div>
                  <strong>
                    {country.flagEmoji} {country.nameFr}
                  </strong>
                  <p style={{ margin: '6px 0' }}>
                    {country.code} • {country.popularFieldIds.length} popular
                    field(s)
                  </p>
                  <span style={badgeStyle}>
                    {country.isActive ? 'active' : 'inactive'}
                  </span>{' '}
                  <span style={badgeStyle}>order {country.displayOrder}</span>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                  <button
                    type="button"
                    onClick={() => startEdit(country)}
                    style={{ ...secondaryButtonStyle, padding: '8px 12px' }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => remove(country)}
                    style={{
                      ...secondaryButtonStyle,
                      padding: '8px 12px',
                      background: '#FEE2E2',
                      color: '#B91C1C',
                    }}
                  >
                    Delete
                  </button>
                </div>
              </div>
            ))}
            {countries.length === 0 ? (
              <p style={mutedTextStyle}>No countries yet.</p>
            ) : null}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
