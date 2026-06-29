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
  fetchInstitutions,
  InstitutionRow,
  linesToArray,
} from '../../lib/catalog-api';
import {
  badgeStyle,
  buttonStyle,
  inputStyle,
  labelStyle,
  mutedTextStyle,
  panelStyle,
  secondaryButtonStyle,
} from '../../lib/ui';

interface InstitutionForm {
  nameFr: string;
  nameEn: string;
  countryId: string;
  isPartner: boolean;
  locationFr: string;
  locationEn: string;
  tuitionLabelFr: string;
  tuitionLabelEn: string;
  languageRequirementsFr: string;
  languageRequirementsEn: string;
  overviewFr: string;
  overviewEn: string;
  studyLevels: string;
  intakePeriods: string;
  programIds: string;
}

const emptyForm: InstitutionForm = {
  nameFr: '',
  nameEn: '',
  countryId: '',
  isPartner: false,
  locationFr: '',
  locationEn: '',
  tuitionLabelFr: '',
  tuitionLabelEn: '',
  languageRequirementsFr: '',
  languageRequirementsEn: '',
  overviewFr: '',
  overviewEn: '',
  studyLevels: '',
  intakePeriods: '',
  programIds: '',
};

export default function InstitutionsPage() {
  const [institutions, setInstitutions] = useState<InstitutionRow[]>([]);
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [filterCountryId, setFilterCountryId] = useState('');
  const [form, setForm] = useState<InstitutionForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadCountries() {
    try {
      const response = await fetchCountries();
      setCountries(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load countries.',
      );
    }
  }

  async function loadInstitutions() {
    setErrorMessage(null);
    try {
      const response = await fetchInstitutions(filterCountryId || undefined);
      setInstitutions(response.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load institutions.',
      );
    }
  }

  useEffect(() => {
    void loadCountries();
  }, []);

  useEffect(() => {
    void loadInstitutions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterCountryId]);

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

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(institution: InstitutionRow) {
    setEditingId(institution.id);
    setStatusMessage(null);
    setErrorMessage(null);
    setForm({
      nameFr: institution.nameFr,
      nameEn: institution.nameEn,
      countryId: institution.countryId,
      isPartner: institution.isPartner,
      locationFr: institution.locationFr,
      locationEn: institution.locationEn,
      tuitionLabelFr: institution.tuitionLabelFr,
      tuitionLabelEn: institution.tuitionLabelEn,
      languageRequirementsFr: institution.languageRequirementsFr,
      languageRequirementsEn: institution.languageRequirementsEn,
      overviewFr: institution.overviewFr,
      overviewEn: institution.overviewEn,
      studyLevels: arrayToLines(institution.studyLevels),
      intakePeriods: arrayToLines(institution.intakePeriods),
      programIds: arrayToLines(institution.programIds),
    });
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      nameFr: form.nameFr,
      nameEn: form.nameEn,
      countryId: form.countryId,
      isPartner: form.isPartner,
      locationFr: form.locationFr,
      locationEn: form.locationEn,
      tuitionLabelFr: form.tuitionLabelFr,
      tuitionLabelEn: form.tuitionLabelEn,
      languageRequirementsFr: form.languageRequirementsFr,
      languageRequirementsEn: form.languageRequirementsEn,
      overviewFr: form.overviewFr,
      overviewEn: form.overviewEn,
      studyLevels: linesToArray(form.studyLevels),
      intakePeriods: linesToArray(form.intakePeriods),
      programIds: linesToArray(form.programIds),
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/catalog/institutions/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Institution updated.');
      } else {
        await apiFetch('/admin/catalog/institutions', { method: 'POST', body });
        setStatusMessage('Institution created.');
      }
      resetForm();
      await loadInstitutions();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to save institution.',
      );
    }
  }

  async function remove(institution: InstitutionRow) {
    if (
      !window.confirm(
        `Delete institution "${institution.nameFr}"? This cannot be undone.`,
      )
    ) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/catalog/institutions/${institution.id}`, {
        method: 'DELETE',
      });
      if (editingId === institution.id) {
        resetForm();
      }
      setStatusMessage('Institution deleted.');
      await loadInstitutions();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to delete institution.',
      );
    }
  }

  return (
    <DashboardShell title="Institutions">
      <div style={{ display: 'grid', gap: 18 }}>
        <StatusBanners statusMessage={statusMessage} errorMessage={errorMessage} />

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>
              {editingId ? 'Edit institution' : 'Add an institution'}
            </h3>
            <p style={mutedTextStyle}>
              Universities and schools. Partner institutions surface first in the
              mobile catalogue.
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
              onChange={(value) =>
                setForm((current) => ({ ...current, countryId: value }))
              }
              options={countrySelectOptions}
            />
            <CheckboxField
              label="KPB partner"
              checked={form.isPartner}
              onChange={(checked) =>
                setForm((current) => ({ ...current, isPartner: checked }))
              }
            />
            <TextField
              label="Location (FR)"
              value={form.locationFr}
              placeholder="Lyon, France"
              onChange={(value) =>
                setForm((current) => ({ ...current, locationFr: value }))
              }
            />
            <TextField
              label="Location (EN)"
              value={form.locationEn}
              placeholder="Lyon, France"
              onChange={(value) =>
                setForm((current) => ({ ...current, locationEn: value }))
              }
            />
            <TextField
              label="Tuition label (FR)"
              value={form.tuitionLabelFr}
              placeholder="À partir de 8 000 € / an"
              onChange={(value) =>
                setForm((current) => ({ ...current, tuitionLabelFr: value }))
              }
            />
            <TextField
              label="Tuition label (EN)"
              value={form.tuitionLabelEn}
              placeholder="From €8,000 / year"
              onChange={(value) =>
                setForm((current) => ({ ...current, tuitionLabelEn: value }))
              }
            />
            <TextField
              label="Language requirements (FR)"
              value={form.languageRequirementsFr}
              placeholder="TCF B2 ou IELTS 6.0"
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  languageRequirementsFr: value,
                }))
              }
            />
            <TextField
              label="Language requirements (EN)"
              value={form.languageRequirementsEn}
              placeholder="TCF B2 or IELTS 6.0"
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  languageRequirementsEn: value,
                }))
              }
            />
            <TextAreaField
              label="Overview (FR)"
              value={form.overviewFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, overviewFr: value }))
              }
            />
            <TextAreaField
              label="Overview (EN)"
              value={form.overviewEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, overviewEn: value }))
              }
            />
            <TextAreaField
              label="Study levels (one per line)"
              value={form.studyLevels}
              placeholder={'Bachelor\nMaster'}
              onChange={(value) =>
                setForm((current) => ({ ...current, studyLevels: value }))
              }
            />
            <TextAreaField
              label="Intake periods (one per line)"
              value={form.intakePeriods}
              placeholder={'Septembre 2026\nJanvier 2027'}
              onChange={(value) =>
                setForm((current) => ({ ...current, intakePeriods: value }))
              }
            />
            <TextAreaField
              label="Program IDs (optional, one per line)"
              value={form.programIds}
              onChange={(value) =>
                setForm((current) => ({ ...current, programIds: value }))
              }
            />
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 12 }}>
              <button type="submit" style={{ ...buttonStyle, flex: 1 }}>
                {editingId ? 'Update institution' : 'Add institution'}
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
          <label style={{ ...labelStyle, maxWidth: 320 }}>
            Filter by country
            <select
              value={filterCountryId}
              onChange={(event) => setFilterCountryId(event.target.value)}
              style={inputStyle}
            >
              <option value="">All countries</option>
              {countries.map((country) => (
                <option key={country.id} value={country.id}>
                  {country.flagEmoji} {country.nameFr}
                </option>
              ))}
            </select>
          </label>
          <p style={mutedTextStyle}>{institutions.length} institution(s).</p>
          <div style={{ display: 'grid', gap: 12 }}>
            {institutions.map((institution) => (
              <div
                key={institution.id}
                style={{
                  border:
                    editingId === institution.id
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
                  <strong>{institution.nameFr}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {countryName.get(institution.countryId) ??
                      institution.countryId}{' '}
                    • {institution.locationFr || '—'}
                  </p>
                  <span style={badgeStyle}>
                    {institution.isPartner ? 'Partner ⭐' : 'Standard'}
                  </span>{' '}
                  <span style={badgeStyle}>
                    {institution.programIds.length} program(s)
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                  <button
                    type="button"
                    onClick={() => startEdit(institution)}
                    style={{ ...secondaryButtonStyle, padding: '8px 12px' }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => remove(institution)}
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
            {institutions.length === 0 ? (
              <p style={mutedTextStyle}>No institutions yet.</p>
            ) : null}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
