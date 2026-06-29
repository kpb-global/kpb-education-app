'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import {
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
  fetchInstitutions,
  fetchPrograms,
  FieldOption,
  InstitutionRow,
  linesToArray,
  PROGRAM_LEVELS,
  ProgramRow,
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

interface ProgramForm {
  institutionId: string;
  countryId: string;
  fieldId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  levelEn: string;
  durationFr: string;
  durationEn: string;
  tuitionFr: string;
  tuitionEn: string;
  languageFr: string;
  languageEn: string;
  requirementsFr: string;
  requirementsEn: string;
}

const emptyForm: ProgramForm = {
  institutionId: '',
  countryId: '',
  fieldId: '',
  nameFr: '',
  nameEn: '',
  levelFr: 'Bachelor',
  levelEn: 'Bachelor',
  durationFr: '',
  durationEn: '',
  tuitionFr: '',
  tuitionEn: '',
  languageFr: '',
  languageEn: '',
  requirementsFr: '',
  requirementsEn: '',
};

const levelOptions = PROGRAM_LEVELS.map((level) => ({
  value: level,
  label: level,
}));

export default function ProgramsPage() {
  const [programs, setPrograms] = useState<ProgramRow[]>([]);
  const [total, setTotal] = useState(0);
  const [institutions, setInstitutions] = useState<InstitutionRow[]>([]);
  const [countries, setCountries] = useState<CountryOption[]>([]);
  const [fields, setFields] = useState<FieldOption[]>([]);
  const [search, setSearch] = useState('');
  const [filterCountryId, setFilterCountryId] = useState('');
  const [filterFieldId, setFilterFieldId] = useState('');
  const [form, setForm] = useState<ProgramForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  async function loadOptions() {
    try {
      const [countriesResponse, fieldsResponse, institutionsResponse] =
        await Promise.all([
          fetchCountries(),
          fetchFields(),
          fetchInstitutions(),
        ]);
      setCountries(countriesResponse.items);
      setFields(fieldsResponse.items);
      setInstitutions(institutionsResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load catalog options.',
      );
    }
  }

  async function loadPrograms() {
    setErrorMessage(null);
    try {
      const response = await fetchPrograms({
        q: search.trim() || undefined,
        countryId: filterCountryId || undefined,
        fieldId: filterFieldId || undefined,
        limit: 200,
      });
      setPrograms(response.items);
      setTotal(response.total);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load programs.',
      );
    }
  }

  useEffect(() => {
    void loadOptions();
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      void loadPrograms();
    }, 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, filterCountryId, filterFieldId]);

  const countryName = useMemo(() => {
    const map = new Map<string, string>();
    countries.forEach((country) =>
      map.set(country.id, `${country.flagEmoji} ${country.nameFr}`),
    );
    return map;
  }, [countries]);

  const institutionName = useMemo(() => {
    const map = new Map<string, string>();
    institutions.forEach((institution) =>
      map.set(institution.id, institution.nameFr),
    );
    return map;
  }, [institutions]);

  const fieldName = useMemo(() => {
    const map = new Map<string, string>();
    fields.forEach((field) => map.set(field.id, field.nameFr));
    return map;
  }, [fields]);

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

  const fieldSelectOptions = useMemo(
    () => [
      { value: '', label: '— Select a field —' },
      ...fields.map((field) => ({ value: field.id, label: field.nameFr })),
    ],
    [fields],
  );

  // Institutions filtered by the chosen country so the FK link stays coherent.
  const institutionSelectOptions = useMemo(() => {
    const relevant = form.countryId
      ? institutions.filter((item) => item.countryId === form.countryId)
      : institutions;
    return [
      { value: '', label: '— Select an institution —' },
      ...relevant.map((item) => ({ value: item.id, label: item.nameFr })),
    ];
  }, [institutions, form.countryId]);

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function startEdit(program: ProgramRow) {
    setEditingId(program.id);
    setStatusMessage(null);
    setErrorMessage(null);
    setForm({
      institutionId: program.institutionId,
      countryId: program.countryId,
      fieldId: program.fieldId,
      nameFr: program.nameFr,
      nameEn: program.nameEn,
      levelFr: program.levelFr,
      levelEn: program.levelEn,
      durationFr: program.durationFr,
      durationEn: program.durationEn,
      tuitionFr: program.tuitionFr,
      tuitionEn: program.tuitionEn,
      languageFr: program.languageFr,
      languageEn: program.languageEn,
      requirementsFr: arrayToLines(program.requirementsFr),
      requirementsEn: arrayToLines(program.requirementsEn),
    });
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      institutionId: form.institutionId,
      countryId: form.countryId,
      fieldId: form.fieldId,
      nameFr: form.nameFr,
      nameEn: form.nameEn,
      levelFr: form.levelFr,
      levelEn: form.levelEn,
      durationFr: form.durationFr,
      durationEn: form.durationEn,
      tuitionFr: form.tuitionFr,
      tuitionEn: form.tuitionEn,
      languageFr: form.languageFr,
      languageEn: form.languageEn,
      requirementsFr: linesToArray(form.requirementsFr),
      requirementsEn: linesToArray(form.requirementsEn),
    };

    try {
      if (editingId) {
        await apiFetch(`/admin/catalog/programs/${editingId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Program updated.');
      } else {
        await apiFetch('/admin/catalog/programs', { method: 'POST', body });
        setStatusMessage('Program created.');
      }
      resetForm();
      await loadPrograms();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to save program.',
      );
    }
  }

  async function remove(program: ProgramRow) {
    if (
      !window.confirm(
        `Delete program "${program.nameFr}"? This cannot be undone.`,
      )
    ) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/catalog/programs/${program.id}`, {
        method: 'DELETE',
      });
      if (editingId === program.id) {
        resetForm();
      }
      setStatusMessage('Program deleted.');
      await loadPrograms();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to delete program.',
      );
    }
  }

  return (
    <DashboardShell title="Programs">
      <div style={{ display: 'grid', gap: 18 }}>
        <StatusBanners statusMessage={statusMessage} errorMessage={errorMessage} />

        <section style={{ ...panelStyle, display: 'grid', gap: 16 }}>
          <div>
            <h3 style={{ marginTop: 0 }}>
              {editingId ? 'Edit program' : 'Add a program'}
            </h3>
            <p style={mutedTextStyle}>
              Formations surfaced in the mobile catalogue. Degree level is
              normalised to the canonical KPB referential on save.
            </p>
          </div>
          <form
            onSubmit={submit}
            style={{ display: 'grid', gap: 14, gridTemplateColumns: '1fr 1fr' }}
          >
            <SelectField
              label="Country"
              value={form.countryId}
              onChange={(value) =>
                setForm((current) => ({
                  ...current,
                  countryId: value,
                  institutionId: '',
                }))
              }
              options={countrySelectOptions}
            />
            <SelectField
              label="Institution"
              value={form.institutionId}
              onChange={(value) =>
                setForm((current) => ({ ...current, institutionId: value }))
              }
              options={institutionSelectOptions}
            />
            <SelectField
              label="Field"
              value={form.fieldId}
              onChange={(value) =>
                setForm((current) => ({ ...current, fieldId: value }))
              }
              options={fieldSelectOptions}
            />
            <SelectField
              label="Degree level (FR)"
              value={form.levelFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, levelFr: value }))
              }
              options={levelOptions}
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
              label="Duration (FR)"
              value={form.durationFr}
              placeholder="3 ans"
              onChange={(value) =>
                setForm((current) => ({ ...current, durationFr: value }))
              }
            />
            <TextField
              label="Duration (EN)"
              value={form.durationEn}
              placeholder="3 years"
              onChange={(value) =>
                setForm((current) => ({ ...current, durationEn: value }))
              }
            />
            <TextField
              label="Tuition (FR)"
              value={form.tuitionFr}
              placeholder="8 000 € / an"
              onChange={(value) =>
                setForm((current) => ({ ...current, tuitionFr: value }))
              }
            />
            <TextField
              label="Tuition (EN)"
              value={form.tuitionEn}
              placeholder="€8,000 / year"
              onChange={(value) =>
                setForm((current) => ({ ...current, tuitionEn: value }))
              }
            />
            <TextField
              label="Language (FR)"
              value={form.languageFr}
              placeholder="Français"
              onChange={(value) =>
                setForm((current) => ({ ...current, languageFr: value }))
              }
            />
            <TextField
              label="Language (EN)"
              value={form.languageEn}
              placeholder="French"
              onChange={(value) =>
                setForm((current) => ({ ...current, languageEn: value }))
              }
            />
            <TextAreaField
              label="Requirements (FR, one per line)"
              value={form.requirementsFr}
              onChange={(value) =>
                setForm((current) => ({ ...current, requirementsFr: value }))
              }
            />
            <TextAreaField
              label="Requirements (EN, one per line)"
              value={form.requirementsEn}
              onChange={(value) =>
                setForm((current) => ({ ...current, requirementsEn: value }))
              }
            />
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 12 }}>
              <button type="submit" style={{ ...buttonStyle, flex: 1 }}>
                {editingId ? 'Update program' : 'Add program'}
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
          <div
            style={{
              display: 'grid',
              gap: 12,
              gridTemplateColumns: '1.4fr 1fr 1fr',
              alignItems: 'end',
            }}
          >
            <label style={labelStyle}>
              Search
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Name or level…"
                style={inputStyle}
              />
            </label>
            <label style={labelStyle}>
              Country
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
            <label style={labelStyle}>
              Field
              <select
                value={filterFieldId}
                onChange={(event) => setFilterFieldId(event.target.value)}
                style={inputStyle}
              >
                <option value="">All fields</option>
                {fields.map((field) => (
                  <option key={field.id} value={field.id}>
                    {field.nameFr}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <p style={mutedTextStyle}>
            Showing {programs.length} of {total} program(s).
          </p>
          <div style={{ display: 'grid', gap: 12 }}>
            {programs.map((program) => (
              <div
                key={program.id}
                style={{
                  border:
                    editingId === program.id
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
                  <strong>{program.nameFr}</strong>
                  <p style={{ margin: '6px 0' }}>
                    {institutionName.get(program.institutionId) ??
                      program.institutionId}{' '}
                    • {countryName.get(program.countryId) ?? program.countryId}
                  </p>
                  <span style={badgeStyle}>{program.levelFr || 'n/a'}</span>{' '}
                  <span style={badgeStyle}>
                    {fieldName.get(program.fieldId) ?? program.fieldId}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                  <button
                    type="button"
                    onClick={() => startEdit(program)}
                    style={{ ...secondaryButtonStyle, padding: '8px 12px' }}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => remove(program)}
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
            {programs.length === 0 ? (
              <p style={mutedTextStyle}>No programs match the current filters.</p>
            ) : null}
          </div>
        </section>
      </div>
    </DashboardShell>
  );
}
