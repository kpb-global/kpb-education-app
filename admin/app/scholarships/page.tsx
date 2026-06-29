'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import {
  CheckboxField,
  SelectField,
  StatusBanners,
  TextAreaField,
  TextField,
} from '../../components/form-controls';
import { apiFetch } from '../../lib/api-client';
import {
  arrayToLines,
  CountryOption,
  fetchCountries,
  fetchFields,
  fetchScholarships,
  FieldOption,
  linesToArray,
  ScholarshipRow,
} from '../../lib/catalog-api';
import {
  badgeStyle,
  buttonStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  secondaryButtonStyle,
  splitList,
} from '../../lib/ui';

interface ScholarshipForm {
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  levelEligibleFr: string;
  levelEligibleEn: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  descriptionFr: string;
  descriptionEn: string;
  advantagesFr: string;
  advantagesEn: string;
  eligibilityFr: string;
  eligibilityEn: string;
  keyRequirementsFr: string;
  keyRequirementsEn: string;
  relatedFieldIds: string[];
  baseMatch: string;
  applicationUrl: string;
  sourceUrl: string;
  isActive: boolean;
  tags: string;
}

const emptyForm: ScholarshipForm = {
  nameFr: '',
  nameEn: '',
  countryId: '',
  countryNameFr: '',
  countryNameEn: '',
  levelEligibleFr: '',
  levelEligibleEn: '',
  typeOfFundingFr: '',
  typeOfFundingEn: '',
  deadlineLabelFr: '',
  deadlineLabelEn: '',
  descriptionFr: '',
  descriptionEn: '',
  advantagesFr: '',
  advantagesEn: '',
  eligibilityFr: '',
  eligibilityEn: '',
  keyRequirementsFr: '',
  keyRequirementsEn: '',
  relatedFieldIds: [],
  baseMatch: '30',
  applicationUrl: '',
  sourceUrl: '',
  isActive: true,
  tags: '',
};

export default function ScholarshipsPage() {
  const [scholarships, setScholarships] = useState<ScholarshipRow[]>([]);
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [fields, setFields] = useState<FieldOption[]>([]);
  const [form, setForm] = useState<ScholarshipForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadOptions() {
    try {
      const [countriesResponse, fieldsResponse] = await Promise.all([
        fetchCountries(),
        fetchFields(),
      ]);
      setCountries(countriesResponse.items);
      setFields(fieldsResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load options.',
      );
    }
  }

  async function loadScholarships() {
    setErrorMessage(null);
    try {
      const response = await fetchScholarships();
      setScholarships(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load scholarships.',
      );
    }
  }

  useEffect(() => {
    void loadOptions();
    void loadScholarships();
  }, []);

  const countryName = useMemo(() => {
    const map = new Map<string, string>();
    countries.forEach((country) =>
      map.set(country.id, `${country.flagEmoji} ${country.nameFr}`),
    );
    return map;
  }, [countries]);

  const countrySelectOptions = useMemo(
    () => [
      { value: '', label: '— Select a country —' },
      ...countries.map((country) => ({
        value: country.id,
        label: `${country.flagEmoji} ${country.nameFr}`,
      })),
    ],
    [countries],
  );

  function onCountryChange(countryId: string) {
    const country = countries.find((item) => item.id === countryId);
    setForm((current) => ({
      ...current,
      countryId,
      countryNameFr: country ? country.nameFr : current.countryNameFr,
      countryNameEn: country ? country.nameEn : current.countryNameEn,
    }));
  }

  function toggleField(fieldId: string) {
    setForm((current) => ({
      ...current,
      relatedFieldIds: current.relatedFieldIds.includes(fieldId)
        ? current.relatedFieldIds.filter((id) => id !== fieldId)
        : [...current.relatedFieldIds, fieldId],
    }));
  }

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(scholarship: ScholarshipRow) {
    setEditingId(scholarship.id);
    setStatusMessage(null);
    setErrorMessage(null);
    setForm({
      nameFr: scholarship.nameFr,
      nameEn: scholarship.nameEn,
      countryId: scholarship.countryId,
      countryNameFr: scholarship.countryNameFr,
      countryNameEn: scholarship.countryNameEn,
      levelEligibleFr: scholarship.levelEligibleFr,
      levelEligibleEn: scholarship.levelEligibleEn,
      typeOfFundingFr: scholarship.typeOfFundingFr,
      typeOfFundingEn: scholarship.typeOfFundingEn,
      deadlineLabelFr: scholarship.deadlineLabelFr,
      deadlineLabelEn: scholarship.deadlineLabelEn,
      descriptionFr: scholarship.descriptionFr,
      descriptionEn: scholarship.descriptionEn,
      advantagesFr: arrayToLines(scholarship.advantagesFr),
      advantagesEn: arrayToLines(scholarship.advantagesEn),
      eligibilityFr: arrayToLines(scholarship.eligibilityFr),
      eligibilityEn: arrayToLines(scholarship.eligibilityEn),
      keyRequirementsFr: arrayToLines(scholarship.keyRequirementsFr),
      keyRequirementsEn: arrayToLines(scholarship.keyRequirementsEn),
      relatedFieldIds: scholarship.relatedFieldIds,
      baseMatch: String(scholarship.baseMatch),
      applicationUrl: scholarship.applicationUrl ?? '',
      sourceUrl: scholarship.sourceUrl ?? '',
      isActive: scholarship.isActive,
      tags: scholarship.tags.join(', '),
    });
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const baseMatchValue = Number(form.baseMatch);
    const body = {
      nameFr: form.nameFr,
      nameEn: form.nameEn,
      countryId: form.countryId,
      countryNameFr: form.countryNameFr,
      countryNameEn: form.countryNameEn,
      levelEligibleFr: form.levelEligibleFr,
      levelEligibleEn: form.levelEligibleEn,
      typeOfFundingFr: form.typeOfFundingFr,
      typeOfFundingEn: form.typeOfFundingEn,
      deadlineLabelFr: form.deadlineLabelFr,
      deadlineLabelEn: form.deadlineLabelEn,
      descriptionFr: form.descriptionFr,
      descriptionEn: form.descriptionEn,
      advantagesFr: linesToArray(form.advantagesFr),
      advantagesEn: linesToArray(form.advantagesEn),
      eligibilityFr: linesToArray(form.eligibilityFr),
      eligibilityEn: linesToArray(form.eligibilityEn),
      keyRequirementsFr: linesToArray(form.keyRequirementsFr),
      keyRequirementsEn: linesToArray(form.keyRequirementsEn),
      relatedFieldIds: form.relatedFieldIds,
      baseMatch: Number.isFinite(baseMatchValue) ? baseMatchValue : 30,
      applicationUrl: form.applicationUrl.trim() || null,
      sourceUrl: form.sourceUrl.trim() || null,
      isActive: form.isActive,
      tags: splitList(form.tags),
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/catalog/scholarships/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Scholarship updated.');
      } else {
        await apiFetch('/admin/catalog/scholarships', { method: 'POST', body });
        setStatusMessage('Scholarship created.');
      }
      resetForm();
      await loadScholarships();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to save scholarship.',
      );
    }
  }

  async function remove(scholarship: ScholarshipRow) {
    if (
      !window.confirm(
        `Delete scholarship "${scholarship.nameFr}"? This cannot be undone.`,
      )
    ) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/catalog/scholarships/${scholarship.id}`, {
        method: 'DELETE',
      });
      if (editingId === scholarship.id) {
        resetForm();
      }
      setStatusMessage('Scholarship deleted.');
      await loadScholarships();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to delete scholarship.',
      );
    }
  }

  return (
    <DashboardShell title="Scholarships">
      <div style={{ display: 'grid', gap: 18 }}>
        <StatusBanners statusMessage={statusMessage} errorMessage={errorMessage} />

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>
              {editingId ? 'Edit scholarship' : 'Add a scholarship'}
            </h3>
            <p style={mutedTextStyle}>
              Manual scholarships are kept separate from the scraper refresh, so
              they are never overwritten.
            </p>
          </div>
          <form
            onSubmit={submit}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
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
            <SelectField
              label="Country"
              value={form.countryId}
              onChange={onCountryChange}
              options={countrySelectOptions}
            />
            <TextField
              label="Base match score (0-100)"
              value={form.baseMatch}
              type="number"
              onChange={(value) =>
                setForm((current) => ({ ...current, baseMatch: value }))
              }
            />
            <TextField
              label="Level eligible (FR)"
              value={form.levelEligibleFr}
              placeholder="Master, Doctorat"
              onChange={(value) =>
                setForm((current) => ({ ...current, levelEligibleFr: value }))
              }
            />
            <TextField
              label="Level eligible (EN)"
              value={form.levelEligibleEn}
              placeholder="Master, Doctorate"
              onChange={(value) =>
                setForm((current) => ({ ...current, levelEligibleEn: value }))
              }
            />
            <TextField
              label="Type of funding (FR)"
              value={form.typeOfFundingFr}
              placeholder="Financement complet"
              onChange={(value) =>
                setForm((current) => ({ ...current, typeOfFundingFr: value }))
              }
            />
            <TextField
              label="Type of funding (EN)"
              value={form.typeOfFundingEn}
              placeholder="Full funding"
              onChange={(value) =>
                setForm((current) => ({ ...current, typeOfFundingEn: value }))
              }
            />
            <TextField
              label="Deadline label (FR)"
              value={form.deadlineLabelFr}
              placeholder="15 janvier 2027"
              onChange={(value) =>
                setForm((current) => ({ ...current, deadlineLabelFr: value }))
              }
            />
            <TextField
              label="Deadline label (EN)"
              value={form.deadlineLabelEn}
              placeholder="January 15, 2027"
              onChange={(value) =>
                setForm((current) => ({ ...current, deadlineLabelEn: value }))
              }
            />
            <TextAreaField
              label="Description (FR)"
              value={form.descriptionFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, descriptionFr: value }))
              }
            />
            <TextAreaField
              label="Description (EN)"
              value={form.descriptionEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, descriptionEn: value }))
              }
            />
            <TextAreaField
              label="Advantages (FR, one per line)"
              value={form.advantagesFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, advantagesFr: value }))
              }
            />
            <TextAreaField
              label="Advantages (EN, one per line)"
              value={form.advantagesEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, advantagesEn: value }))
              }
            />
            <TextAreaField
              label="Eligibility (FR, one per line)"
              value={form.eligibilityFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, eligibilityFr: value }))
              }
            />
            <TextAreaField
              label="Eligibility (EN, one per line)"
              value={form.eligibilityEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, eligibilityEn: value }))
              }
            />
            <TextAreaField
              label="Key requirements (FR, one per line)"
              value={form.keyRequirementsFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, keyRequirementsFr: value }))
              }
            />
            <TextAreaField
              label="Key requirements (EN, one per line)"
              value={form.keyRequirementsEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, keyRequirementsEn: value }))
              }
            />
            <TextField
              label="Application URL"
              value={form.applicationUrl}
              placeholder="https://…"
              fullWidth
              onChange={(value) =>
                setForm((current) => ({ ...current, applicationUrl: value }))
              }
            />
            <TextField
              label="Tags (comma separated)"
              value={form.tags}
              placeholder="canada, master, leadership"
              fullWidth
              onChange={(value) =>
                setForm((current) => ({ ...current, tags: value }))
              }
            />
            <div style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Related fields
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
                        checked={form.relatedFieldIds.includes(field.id)}
                        onChange={() => toggleField(field.id)}
                      />
                      {field.nameFr}
                    </label>
                  ))
                )}
              </div>
            </div>
            <CheckboxField
              label="Active (visible in app)"
              checked={form.isActive}
              onChange={(checked) =>
                setForm((current) => ({ ...current, isActive: checked }))
              }
            />
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 12 }}>
              <button type="submit" style={{ ...buttonStyle, flex: 1 }}>
                {editingId ? 'Update scholarship' : 'Add scholarship'}
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
          <p style={mutedTextStyle}>{scholarships.length} scholarship(s).</p>
          <div style={{ display: 'grid', gap: 12 }}>
            {scholarships.map((scholarship) => (
              <div
                key={scholarship.id}
                style={{
                  border:
                    editingId === scholarship.id
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
                  <strong>{scholarship.nameFr}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {countryName.get(scholarship.countryId) ??
                      (scholarship.countryNameFr || scholarship.countryId)}{' '}
                    • {scholarship.typeOfFundingFr || '—'}
                  </p>
                  <span style={badgeStyle}>
                    {scholarship.isActive ? 'active' : 'inactive'}
                  </span>{' '}
                  <span style={badgeStyle}>
                    {scholarship.sourceKey ? 'scraped' : 'manual'}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                  <button
                    type="button"
                    onClick={() => startEdit(scholarship)}
                    style={{ ...secondaryButtonStyle, padding: '8px 12px' }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => remove(scholarship)}
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
            {scholarships.length === 0 ? (
              <p style={mutedTextStyle}>No scholarships yet.</p>
            ) : null}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
