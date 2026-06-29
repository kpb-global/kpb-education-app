'use client';

import { FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import {
  Alert,
  Badge,
  Button,
  Card,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import { mutedTextStyle } from '../../lib/ui';

interface ForumCategoryItem {
  id: string;
  label: { fr: string; en: string };
  description: { fr: string; en: string };
  displayOrder: number;
  status: string;
}

interface ForumTagItem {
  id: string;
  label: { fr: string; en: string };
  description: { fr: string; en: string };
  displayOrder: number;
  status: string;
}

interface ModerationItem {
  id: string;
  subject: string;
  targetType: string;
  reportsCount: number;
  suggestedAction: string;
}

const EMPTY_FORM = {
  labelFr: '',
  labelEn: '',
  descriptionFr: '',
  descriptionEn: '',
  displayOrder: '1',
  status: 'draft',
};

type TaxonomyForm = typeof EMPTY_FORM;

// Shared editor used by both the categories and the tags column.
function TaxonomyEditor({
  title,
  description,
  form,
  setForm,
  editingId,
  onCancelEdit,
  onSubmit,
  items,
  onSelect,
}: Readonly<{
  title: string;
  description: string;
  form: TaxonomyForm;
  setForm: (updater: (current: TaxonomyForm) => TaxonomyForm) => void;
  editingId: string | null;
  onCancelEdit: () => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  items: {
    id: string;
    label: { fr: string };
    description: { fr: string };
    displayOrder: number;
    status: string;
  }[];
  onSelect: (id: string) => void;
}>) {
  return (
    <Card style={{ display: 'grid', gap: 'var(--space-3)' }}>
      <div>
        <h3 style={{ marginTop: 0 }}>{title}</h3>
        <p style={mutedTextStyle}>{description}</p>
      </div>
      <form onSubmit={onSubmit} style={{ display: 'grid', gap: 'var(--space-3)' }}>
        <Field label="Label (FR)">
          {({ id }) => (
            <Input
              id={id}
              value={form.labelFr}
              onChange={(event) =>
                setForm((current) => ({ ...current, labelFr: event.target.value }))
              }
            />
          )}
        </Field>
        <Field label="Label (EN)">
          {({ id }) => (
            <Input
              id={id}
              value={form.labelEn}
              onChange={(event) =>
                setForm((current) => ({ ...current, labelEn: event.target.value }))
              }
            />
          )}
        </Field>
        <Field label="Description (FR)">
          {({ id }) => (
            <Textarea
              id={id}
              value={form.descriptionFr}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  descriptionFr: event.target.value,
                }))
              }
            />
          )}
        </Field>
        <Field label="Description (EN)">
          {({ id }) => (
            <Textarea
              id={id}
              value={form.descriptionEn}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  descriptionEn: event.target.value,
                }))
              }
            />
          )}
        </Field>
        <div
          style={{
            display: 'grid',
            gap: 'var(--space-3)',
            gridTemplateColumns: '1fr 1fr',
          }}
        >
          <Field label="Display order">
            {({ id }) => (
              <Input
                id={id}
                type="number"
                value={form.displayOrder}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    displayOrder: event.target.value,
                  }))
                }
              />
            )}
          </Field>
          <Field label="Status">
            {({ id }) => (
              <Select
                id={id}
                value={form.status}
                onChange={(event) =>
                  setForm((current) => ({ ...current, status: event.target.value }))
                }
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
                <option value="archived">Archived</option>
              </Select>
            )}
          </Field>
        </div>
        <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
          <Button type="submit">{editingId ? 'Update' : 'Add'}</Button>
          {editingId ? (
            <Button type="button" variant="secondary" onClick={onCancelEdit}>
              Cancel
            </Button>
          ) : null}
        </div>
      </form>
      <div style={{ display: 'grid', gap: 'var(--space-2)' }}>
        {items.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => onSelect(item.id)}
            aria-pressed={editingId === item.id}
            style={{
              textAlign: 'left',
              border:
                editingId === item.id
                  ? '2px solid var(--brand)'
                  : '1px solid var(--border)',
              borderRadius: 'var(--radius-md)',
              padding: 'var(--space-3)',
              background: 'var(--surface)',
              cursor: 'pointer',
              display: 'grid',
              gap: 'var(--space-2)',
            }}
          >
            <strong>{item.label.fr}</strong>
            <span style={mutedTextStyle}>{item.description.fr}</span>
            <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <StatusBadge status={item.status} />
              <span style={{ ...mutedTextStyle, fontSize: 'var(--text-xs)' }}>
                order {item.displayOrder}
              </span>
            </span>
          </button>
        ))}
      </div>
    </Card>
  );
}

export default function CommunityPage() {
  const { session } = useAdminAuth();
  const [forumCategories, setForumCategories] = useState<ForumCategoryItem[]>([]);
  const [forumTags, setForumTags] = useState<ForumTagItem[]>([]);
  const [moderationQueue, setModerationQueue] = useState<ModerationItem[]>([]);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [categoryForm, setCategoryForm] = useState<TaxonomyForm>(EMPTY_FORM);
  const [tagForm, setTagForm] = useState<TaxonomyForm>(EMPTY_FORM);
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [editingTagId, setEditingTagId] = useState<string | null>(null);

  async function loadCommunity() {
    setErrorMessage(null);
    try {
      const [categoriesResponse, tagsResponse, moderationResponse] =
        await Promise.all([
          apiFetch<{ items: ForumCategoryItem[] }>('/admin/forum-categories'),
          apiFetch<{ items: ForumTagItem[] }>('/admin/forum-tags'),
          apiFetch<{ items: ModerationItem[] }>('/admin/forum-moderation'),
        ]);
      setForumCategories(categoriesResponse.items);
      setForumTags(tagsResponse.items);
      setModerationQueue(moderationResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to load community.',
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadCommunity();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  async function submitCategory(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      label: { fr: categoryForm.labelFr, en: categoryForm.labelEn },
      description: {
        fr: categoryForm.descriptionFr,
        en: categoryForm.descriptionEn,
      },
      displayOrder: Number(categoryForm.displayOrder),
      status: categoryForm.status,
    };

    try {
      if (editingCategoryId) {
        await apiFetch(`/admin/forum-categories/${editingCategoryId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Forum category updated successfully.');
      } else {
        await apiFetch('/admin/forum-categories', { method: 'POST', body });
        setStatusMessage('Forum category created successfully.');
      }
      setCategoryForm(EMPTY_FORM);
      setEditingCategoryId(null);
      await loadCommunity();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create category.',
      );
    }
  }

  async function submitTag(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      label: { fr: tagForm.labelFr, en: tagForm.labelEn },
      description: { fr: tagForm.descriptionFr, en: tagForm.descriptionEn },
      displayOrder: Number(tagForm.displayOrder),
      status: tagForm.status,
    };

    try {
      if (editingTagId) {
        await apiFetch(`/admin/forum-tags/${editingTagId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage('Forum topic tag updated successfully.');
      } else {
        await apiFetch('/admin/forum-tags', { method: 'POST', body });
        setStatusMessage('Forum topic tag created successfully.');
      }
      setTagForm(EMPTY_FORM);
      setEditingTagId(null);
      await loadCommunity();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : 'Unable to create tag.',
      );
    }
  }

  return (
    <DashboardShell title="Community">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'grid',
            gap: 'var(--space-5)',
            gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          }}
        >
          <TaxonomyEditor
            title="Forum categories"
            description="Structure the student community by adding visible topic families."
            form={categoryForm}
            setForm={setCategoryForm}
            editingId={editingCategoryId}
            onCancelEdit={() => {
              setEditingCategoryId(null);
              setCategoryForm(EMPTY_FORM);
            }}
            onSubmit={submitCategory}
            items={forumCategories}
            onSelect={(id) => {
              const category = forumCategories.find((item) => item.id === id);
              if (!category) return;
              setEditingCategoryId(id);
              setCategoryForm({
                labelFr: category.label.fr,
                labelEn: category.label.en,
                descriptionFr: category.description.fr,
                descriptionEn: category.description.en,
                displayOrder: String(category.displayOrder),
                status: category.status,
              });
            }}
          />

          <TaxonomyEditor
            title="Forum topic tags"
            description="Add lightweight tags used to guide discussions and discovery."
            form={tagForm}
            setForm={setTagForm}
            editingId={editingTagId}
            onCancelEdit={() => {
              setEditingTagId(null);
              setTagForm(EMPTY_FORM);
            }}
            onSubmit={submitTag}
            items={forumTags}
            onSelect={(id) => {
              const tag = forumTags.find((item) => item.id === id);
              if (!tag) return;
              setEditingTagId(id);
              setTagForm({
                labelFr: tag.label.fr,
                labelEn: tag.label.en,
                descriptionFr: tag.description.fr,
                descriptionEn: tag.description.en,
                displayOrder: String(tag.displayOrder),
                status: tag.status,
              });
            }}
          />
        </div>

        <Card>
          <h3 style={{ marginTop: 0 }}>Moderation queue</h3>
          <p style={mutedTextStyle}>
            Reported items remain visible here for moderator follow-up and
            escalation.
          </p>
          <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
            {moderationQueue.map((item) => (
              <div
                key={item.id}
                style={{
                  borderTop: '1px solid var(--border)',
                  paddingTop: 'var(--space-3)',
                  display: 'grid',
                  gap: 'var(--space-2)',
                }}
              >
                <strong>{item.subject}</strong>
                <span style={mutedTextStyle}>
                  {item.targetType} • {item.reportsCount} reports
                </span>
                <span>
                  <Badge variant="warning">{item.suggestedAction}</Badge>
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </DashboardShell>
  );
}
