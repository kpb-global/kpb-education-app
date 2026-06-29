'use client';

import { FormEvent, useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import {
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
  FieldRow,
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
} from '../../lib/ui';

interface FieldForm {
  nameFr: string;
  nameEn: string;
  descriptionFr: string;
  descriptionEn: string;
  subjectsFr: string;
  subjectsEn: string;
  careersFr: string;
  careersEn: string;
  dailyLifeFr: string;
  dailyLifeEn: string;
  skillsFr: string;
  skillsEn: string;
  personalityTraitsFr: string;
  personalityTraitsEn: string;
  relatedCountryIds: string[];
  relatedScholarshipIds: string[];
  accentColorHex: string;
}

const emptyForm: FieldForm = {
  nameFr: '',
  nameEn: '',
  descriptionFr: '',
  descriptionEn: '',
  subjectsFr: '',
  subjectsEn: '',
  careersFr: '',
  careersEn: '',
  dailyLifeFr: '',
  dailyLifeEn: '',
  skillsFr: '',
  skillsEn: '',
  personalityTraitsFr: '',
  personalityTraitsEn: '',
  relatedCountryIds: [],
  relatedScholarshipIds: [],
  accentColorHex: '',
};

export default function FieldsPage() {
  const [fields, setFields] = useState<FieldRow[]>([]);
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [scholarships, setScholarships] = useState<ScholarshipRow[]>([]);
  const [form, setForm] = useState<FieldForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadFields() {
    setErrorMessage(null);
    try {
      const response = await fetchFields();
      setFields(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load fields.',
      );
    }
  }

  async function loadOptions() {
    try {
      const [countriesResponse, scholarshipsResponse] = await Promise.all([
        fetchCountries(),
        fetchScholarships(),
      ]);
      setCountries(countriesResponse.items);
      setScholarships(scholarshipsResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load options.',
      );
    }
  }

  useEffect(() => {
    void loadFields();
    void loadOptions();
  }, []);

  function toggleCountry(countryId: string) {
    setForm((current) => ({
      ...current,
      relatedCountryIds: current.relatedCountryIds.includes(countryId)
        ? current.relatedCountryIds.filter((id) => id !== countryId)
        : [...current.relatedCountryIds, countryId],
    }));
  }

  function toggleScholarship(scholarshipId: string) {
    setForm((current) => ({
      ...current,
      relatedScholarshipIds: current.relatedScholarshipIds.includes(
        scholarshipId,
      )
        ? current.relatedScholarshipIds.filter((id) => id !== scholarshipId)
        : [...current.relatedScholarshipIds, scholarshipId],
    }));
  }

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(field: FieldRow) {
    setEditingId(field.id);
    setStatusMessage(null);
    setErrorMessage(null);
    setForm({
      nameFr: field.nameFr,
      nameEn: field.nameEn,
      descriptionFr: field.descriptionFr,
      descriptionEn: field.descriptionEn,
      subjectsFr: arrayToLines(field.subjectsFr),
      subjectsEn: arrayToLines(field.subjectsEn),
      careersFr: arrayToLines(field.careersFr),
      careersEn: arrayToLines(field.careersEn),
      dailyLifeFr: arrayToLines(field.dailyLifeFr),
      dailyLifeEn: arrayToLines(field.dailyLifeEn),
      skillsFr: arrayToLines(field.skillsFr),
      skillsEn: arrayToLines(field.skillsEn),
      personalityTraitsFr: arrayToLines(field.personalityTraitsFr),
      personalityTraitsEn: arrayToLines(field.personalityTraitsEn),
      relatedCountryIds: field.relatedCountryIds,
      relatedScholarshipIds: field.relatedScholarshipIds,
      accentColorHex: field.accentColorHex ?? '',
    });
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      nameFr: form.nameFr,
      nameEn: form.nameEn,
      descriptionFr: form.descriptionFr,
      descriptionEn: form.descriptionEn,
      subjectsFr: linesToArray(form.subjectsFr),
      subjectsEn: linesToArray(form.subjectsEn),
      careersFr: linesToArray(form.careersFr),
      careersEn: linesToArray(form.careersEn),
      dailyLifeFr: linesToArray(form.dailyLifeFr),
      dailyLifeEn: linesToArray(form.dailyLifeEn),
      skillsFr: linesToArray(form.skillsFr),
      skillsEn: linesToArray(form.skillsEn),
      personalityTraitsFr: linesToArray(form.personalityTraitsFr),
      personalityTraitsEn: linesToArray(form.personalityTraitsEn),
      relatedCountryIds: form.relatedCountryIds,
      relatedScholarshipIds: form.relatedScholarshipIds,
      accentColorHex: form.accentColorHex.trim() || null,
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/catalog/fields/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Field updated.');
      } else {
        await apiFetch('/admin/catalog/fields', { method: 'POST', body });
        setStatusMessage('Field created.');
      }
      resetForm();
      await loadFields();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to save field.',
      );
    }
  }

  async function remove(field: FieldRow) {
    if (
      !window.confirm(`Delete field "${field.nameFr}"? This cannot be undone.`)
    ) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/catalog/fields/${field.id}`, { method: 'DELETE' });
      if (editingId === field.id) {
        resetForm();
      }
      setStatusMessage('Field deleted.');
      await loadFields();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to delete field.',
      );
    }
  }

  return (
    <DashboardShell title="Fields">
      <div style={{ display: 'grid', gap: 18 }}>
        <StatusBanners statusMessage={statusMessage} errorMessage={errorMessage} />

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>
              {editingId ? 'Edit field' : 'Add a field'}
            </h3>
            <p style={mutedTextStyle}>
              Study fields (filières) powering orientation and discovery. List
              inputs take one item per line.
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
              label="Subjects (FR, one per line)"
              value={form.subjectsFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, subjectsFr: value }))
              }
            />
            <TextAreaField
              label="Subjects (EN, one per line)"
              value={form.subjectsEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, subjectsEn: value }))
              }
            />
            <TextAreaField
              label="Careers (FR, one per line)"
              value={form.careersFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, careersFr: value }))
              }
            />
            <TextAreaField
              label="Careers (EN, one per line)"
              value={form.careersEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, careersEn: value }))
              }
            />
            <TextAreaField
              label="Daily life (FR, one per line)"
              value={form.dailyLifeFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, dailyLifeFr: value }))
              }
            />
            <TextAreaField
              label="Daily life (EN, one per line)"
              value={form.dailyLifeEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, dailyLifeEn: value }))
              }
            />
            <TextAreaField
              label="Skills (FR, one per line)"
              value={form.skillsFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, skillsFr: value }))
              }
            />
            <TextAreaField
              label="Skills (EN, one per line)"
              value={form.skillsEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, skillsEn: value }))
              }
            />
            <TextAreaField
              label="Personality traits (FR, one per line)"
              value={form.personalityTraitsFr}
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  personalityTraitsFr: value,
                }))
              }
            />
            <TextAreaField
              label="Personality traits (EN, one per line)"
              value={form.personalityTraitsEn}
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  personalityTraitsEn: value,
                }))
              }
            />
            <TextField
              label="Accent color (hex)"
              value={form.accentColorHex}
              placeholder="#1D4ED8"
              fullWidth
              onChange={(value) =>
                setForm((current) => ({ ...current, accentColorHex: value }))
              }
            />
            <div style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Related countries
              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: 10,
                  fontWeight: 400,
                }}
              >
                {countries.length === 0 ? (
                  <span style={mutedTextStyle}>No countries available.</span>
                ) : (
                  countries.map((country) => (
                    <label
                      key={country.id}
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
                        checked={form.relatedCountryIds.includes(country.id)}
                        onChange={() => toggleCountry(country.id)}
                      />
                      {country.flagEmoji} {country.nameFr}
                    </label>
                  ))
                )}
              </div>
            </div>
            <div style={{ ...labelStyle, gridColumn: '1 / -1' }}>
              Related scholarships
              <div
                style={{
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: 10,
                  fontWeight: 400,
                  maxHeight: 200,
                  overflowY: 'auto',
                }}
              >
                {scholarships.length === 0 ? (
                  <span style={mutedTextStyle}>No scholarships available.</span>
                ) : (
                  scholarships.map((scholarship) => (
                    <label
                      key={scholarship.id}
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
                        checked={form.relatedScholarshipIds.includes(
                          scholarship.id,
                        )}
                        onChange={() => toggleScholarship(scholarship.id)}
                      />
                      {scholarship.nameFr}
                    </label>
                  ))
                )}
              </div>
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 12 }}>
              <button type="submit" style={{ ...buttonStyle, flex: 1 }}>
                {editingId ? 'Update field' : 'Add field'}
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
          <p style={mutedTextStyle}>{fields.length} field(s).</p>
          <div style={{ display: 'grid', gap: 12 }}>
            {fields.map((field) => (
              <div
                key={field.id}
                style={{
                  border:
                    editingId === field.id
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
                  <strong>{field.nameFr}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {field.careersFr.length} career(s) •{' '}
                    {field.relatedCountryIds.length} country link(s)
                  </p>
                  <span style={badgeStyle}>
                    {field.relatedScholarshipIds.length} scholarship link(s)
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                  <button
                    type="button"
                    onClick={() => startEdit(field)}
                    style={{ ...secondaryButtonStyle, padding: '8px 12px' }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => remove(field)}
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
            {fields.length === 0 ? (
              <p style={mutedTextStyle}>No fields yet.</p>
            ) : null}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
